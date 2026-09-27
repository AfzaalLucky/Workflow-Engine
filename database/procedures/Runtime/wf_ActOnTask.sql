-- Central workhorse: approve, reject, or return a task. Transactional and
-- row-locked so concurrent actors on the same group task can't both
-- succeed. Never trusts the caller's claim of identity/role for
-- authorization -- re-validates against the task's actual assignment.
--
-- On Approve, if the stage's approval rules are now fully satisfied, sets
-- @NeedsRouting = 1 and @RoutingFromStageId so the caller can resolve the
-- next stage (via wf_GetCandidateTransitions + NCalc) and call
-- wf_AdvanceToStage. This proc never decides routing itself -- except
-- when the satisfied stage was entered via a ReturnToOrigin return rule:
-- then @ResumeToStageId names the stage that issued the return, and the
-- caller advances there directly instead of evaluating transitions.
CREATE OR ALTER PROCEDURE dbo.wf_ActOnTask
    @ApprovalTaskId      BIGINT,
    @ActorUserId         UNIQUEIDENTIFIER,
    @ActorRoleCodes      dbo.wf_RoleCodeList READONLY,
    @Action              VARCHAR(10),           -- Approve | Reject | Return
    @Comments            NVARCHAR(1000) = NULL,
    @ReturnToStageId     INT = NULL,
    @WorkflowInstanceId  UNIQUEIDENTIFIER OUTPUT,
    @NeedsRouting        BIT OUTPUT,
    @RoutingFromStageId  INT OUTPUT,
    @ResumeToStageId     INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @NeedsRouting = 0;
    SET @RoutingFromStageId = NULL;
    SET @ResumeToStageId = NULL;

    BEGIN TRAN;

    DECLARE @InstanceStageId BIGINT, @ApprovalRuleId INT, @StageId INT,
            @AssignedToUserId UNIQUEIDENTIFIER, @AssignedToRoleCode VARCHAR(50), @AssignedToGroupId INT;

    SELECT @InstanceStageId = t.InstanceStageId, @WorkflowInstanceId = t.WorkflowInstanceId,
           @ApprovalRuleId = t.ApprovalRuleId, @AssignedToUserId = t.AssignedToUserId,
           @AssignedToRoleCode = t.AssignedToRoleCode, @AssignedToGroupId = t.AssignedToGroupId
    FROM dbo.wf_ApprovalTask t WITH (UPDLOCK, ROWLOCK)
    WHERE t.ApprovalTaskId = @ApprovalTaskId AND t.Status = 'Pending';

    IF @InstanceStageId IS NULL
    BEGIN
        ROLLBACK TRAN;
        THROW 51010, 'Task not found or already completed.', 1;
    END

    SELECT @StageId = StageId FROM dbo.wf_WorkflowInstanceStage WHERE InstanceStageId = @InstanceStageId;

    DECLARE @Authorized BIT = 0;
    IF @AssignedToUserId IS NOT NULL AND @AssignedToUserId = @ActorUserId
        SET @Authorized = 1;
    ELSE IF @AssignedToRoleCode IS NOT NULL AND EXISTS (SELECT 1 FROM @ActorRoleCodes WHERE RoleCode = @AssignedToRoleCode)
        SET @Authorized = 1;
    ELSE IF @AssignedToGroupId IS NOT NULL AND (
        EXISTS (SELECT 1 FROM dbo.wf_ApprovalGroupMember m WHERE m.ApprovalGroupId = @AssignedToGroupId AND m.MemberType = 'User' AND m.UserId = @ActorUserId AND m.IsActive = 1)
        OR EXISTS (SELECT 1 FROM dbo.wf_ApprovalGroupMember m INNER JOIN @ActorRoleCodes r ON r.RoleCode = m.RoleCode WHERE m.ApprovalGroupId = @AssignedToGroupId AND m.MemberType = 'Role' AND m.IsActive = 1)
    )
        SET @Authorized = 1;

    IF @Authorized = 0
    BEGIN
        ROLLBACK TRAN;
        THROW 51011, 'Actor is not authorized to act on this task.', 1;
    END

    IF @Action = 'Reject'
    BEGIN
        UPDATE dbo.wf_ApprovalTask SET Status = 'Rejected', CompletedByUserId = @ActorUserId, Comments = @Comments, CompletedAt = SYSUTCDATETIME()
        WHERE ApprovalTaskId = @ApprovalTaskId;

        -- Instance-wide, not just this stage visit: rejecting one branch of a
        -- parallel gate must also close the sibling branches and their tasks.
        UPDATE dbo.wf_ApprovalTask SET Status = 'Cancelled'
        WHERE WorkflowInstanceId = @WorkflowInstanceId AND Status = 'Pending';

        UPDATE dbo.wf_WorkflowInstanceStage SET Status = 'Rejected', ExitedAt = SYSUTCDATETIME() WHERE InstanceStageId = @InstanceStageId;
        UPDATE dbo.wf_WorkflowInstanceStage SET Status = 'Cancelled', ExitedAt = SYSUTCDATETIME()
        WHERE WorkflowInstanceId = @WorkflowInstanceId AND Status = 'Active';
        UPDATE dbo.wf_WorkflowInstance SET Status = 'Rejected', CompletedAt = SYSUTCDATETIME() WHERE WorkflowInstanceId = @WorkflowInstanceId;

        INSERT INTO dbo.wf_ApprovalAction (WorkflowInstanceId, InstanceStageId, ApprovalTaskId, ActionType, ActorUserId, OldStatus, NewStatus, OldStageId, Comments)
        VALUES (@WorkflowInstanceId, @InstanceStageId, @ApprovalTaskId, 'Reject', @ActorUserId, 'InProgress', 'Rejected', @StageId, @Comments);

        EXEC dbo.wf_EnqueueEvent @WorkflowInstanceId = @WorkflowInstanceId, @EventType = 'InstanceRejected',
            @ActorUserId = @ActorUserId, @StageId = @StageId, @Comments = @Comments;
    END
    ELSE IF @Action = 'Return'
    BEGIN
        DECLARE @ResolvedReturnToStageId INT, @ResetApprovalsOnReturn BIT, @RequireComment BIT, @ResumeMode VARCHAR(20);

        IF @ReturnToStageId IS NOT NULL
            SELECT @ResolvedReturnToStageId = ToStageId, @ResetApprovalsOnReturn = ResetApprovalsOnReturn,
                   @RequireComment = RequireComment, @ResumeMode = ResumeMode
            FROM dbo.wf_ReturnRule WHERE FromStageId = @StageId AND ToStageId = @ReturnToStageId;
        ELSE
            SELECT TOP 1 @ResolvedReturnToStageId = ToStageId, @ResetApprovalsOnReturn = ResetApprovalsOnReturn,
                   @RequireComment = RequireComment, @ResumeMode = ResumeMode
            FROM dbo.wf_ReturnRule WHERE FromStageId = @StageId
            ORDER BY ReturnRuleId;

        IF @ResolvedReturnToStageId IS NULL
        BEGIN
            ROLLBACK TRAN;
            THROW 51012, 'No return rule configured for this stage.', 1;
        END
        IF @RequireComment = 1 AND (@Comments IS NULL OR LTRIM(RTRIM(@Comments)) = '')
        BEGIN
            ROLLBACK TRAN;
            THROW 51013, 'A comment is required to return this task.', 1;
        END

        UPDATE dbo.wf_ApprovalTask SET Status = 'Returned', CompletedByUserId = @ActorUserId, Comments = @Comments, CompletedAt = SYSUTCDATETIME()
        WHERE ApprovalTaskId = @ApprovalTaskId;

        -- Instance-wide: returning from one branch of a parallel gate also
        -- closes the sibling branches and the gate itself.
        UPDATE dbo.wf_ApprovalTask SET Status = 'Cancelled'
        WHERE WorkflowInstanceId = @WorkflowInstanceId AND Status = 'Pending';

        UPDATE dbo.wf_WorkflowInstanceStage SET Status = 'Returned', ExitedAt = SYSUTCDATETIME() WHERE InstanceStageId = @InstanceStageId;
        UPDATE dbo.wf_WorkflowInstanceStage SET Status = 'Cancelled', ExitedAt = SYSUTCDATETIME()
        WHERE WorkflowInstanceId = @WorkflowInstanceId AND Status = 'Active';

        -- ReturnToOrigin: remember where to come back to. A return issued from
        -- a parallel branch resumes at the gate (container), since a lone
        -- branch cannot be re-entered outside its group.
        DECLARE @ReturnedFromStageId INT = NULL;
        IF @ResumeMode = 'ReturnToOrigin'
        BEGIN
            DECLARE @OriginParallelGroupId INT;
            SELECT @OriginParallelGroupId = ParallelGroupId FROM dbo.wf_Stage WHERE StageId = @StageId AND StageType = 'Approval';

            IF @OriginParallelGroupId IS NOT NULL
                SELECT @ReturnedFromStageId = StageId FROM dbo.wf_Stage
                WHERE ParallelGroupId = @OriginParallelGroupId AND StageType = 'ParallelGroup';
            ELSE
                SET @ReturnedFromStageId = @StageId;
        END

        IF @ResetApprovalsOnReturn = 1
        BEGIN
            DECLARE @ToStageOrder INT, @FromStageOrder INT;
            SELECT @ToStageOrder = StageOrder FROM dbo.wf_Stage WHERE StageId = @ResolvedReturnToStageId;
            SELECT @FromStageOrder = StageOrder FROM dbo.wf_Stage WHERE StageId = @StageId;

            UPDATE wis
            SET Status = 'Superseded', ExitedAt = SYSUTCDATETIME()
            FROM dbo.wf_WorkflowInstanceStage wis
            INNER JOIN dbo.wf_Stage s ON s.StageId = wis.StageId
            WHERE wis.WorkflowInstanceId = @WorkflowInstanceId
              AND s.StageOrder > @ToStageOrder AND s.StageOrder <= @FromStageOrder
              AND wis.Status IN ('Approved', 'Returned');
        END

        DECLARE @ReturnAttempt INT;
        SELECT @ReturnAttempt = ISNULL(MAX(AttemptNumber), 0) + 1
        FROM dbo.wf_WorkflowInstanceStage WHERE WorkflowInstanceId = @WorkflowInstanceId AND StageId = @ResolvedReturnToStageId;

        DECLARE @ReturnInstanceStageId BIGINT;
        INSERT INTO dbo.wf_WorkflowInstanceStage (WorkflowInstanceId, StageId, Status, AttemptNumber, ReturnedFromStageId)
        VALUES (@WorkflowInstanceId, @ResolvedReturnToStageId, 'Active', @ReturnAttempt, @ReturnedFromStageId);
        SET @ReturnInstanceStageId = SCOPE_IDENTITY();

        -- If the return target has its own approver (e.g. a dedicated
        -- "return from X" stage), it's immediately actionable -- create its
        -- task(s) now rather than waiting on an explicit Resume call, which
        -- exists only for return targets with no approver (e.g. sending
        -- back to the original requester to edit and resubmit).
        DECLARE @ReturnToHasRules BIT;
        SET @ReturnToHasRules = CASE WHEN EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @ResolvedReturnToStageId) THEN 1 ELSE 0 END;

        DECLARE @NewInstanceStatus VARCHAR(20);
        IF @ReturnToHasRules = 1
        BEGIN
            EXEC dbo.wf_CreateTasksForStage @InstanceStageId = @ReturnInstanceStageId;
            SET @NewInstanceStatus = 'InProgress';
        END
        ELSE
        BEGIN
            SET @NewInstanceStatus = 'Returned';
        END

        UPDATE dbo.wf_WorkflowInstance SET Status = @NewInstanceStatus, CurrentStageId = @ResolvedReturnToStageId WHERE WorkflowInstanceId = @WorkflowInstanceId;

        INSERT INTO dbo.wf_ApprovalAction (WorkflowInstanceId, InstanceStageId, ApprovalTaskId, ActionType, ActorUserId, OldStatus, NewStatus, OldStageId, NewStageId, Comments)
        VALUES (@WorkflowInstanceId, @ReturnInstanceStageId, @ApprovalTaskId, 'Return', @ActorUserId, 'InProgress', @NewInstanceStatus, @StageId, @ResolvedReturnToStageId, @Comments);

        EXEC dbo.wf_EnqueueEvent @WorkflowInstanceId = @WorkflowInstanceId, @EventType = 'InstanceReturned',
            @ActorUserId = @ActorUserId, @StageId = @ResolvedReturnToStageId, @Comments = @Comments;
    END
    ELSE IF @Action = 'Approve'
    BEGIN
        UPDATE dbo.wf_ApprovalTask SET Status = 'Approved', CompletedByUserId = @ActorUserId, Comments = @Comments, CompletedAt = SYSUTCDATETIME()
        WHERE ApprovalTaskId = @ApprovalTaskId;

        INSERT INTO dbo.wf_ApprovalAction (WorkflowInstanceId, InstanceStageId, ApprovalTaskId, ActionType, ActorUserId, OldStatus, NewStatus, OldStageId, Comments)
        VALUES (@WorkflowInstanceId, @InstanceStageId, @ApprovalTaskId, 'Approve', @ActorUserId, 'InProgress', 'Approved', @StageId, @Comments);

        DECLARE @TotalForRule INT, @ApprovedForRule INT, @RequiredForRule INT;
        SELECT @TotalForRule = COUNT(*), @ApprovedForRule = SUM(CASE WHEN Status = 'Approved' THEN 1 ELSE 0 END)
        FROM dbo.wf_ApprovalTask WHERE InstanceStageId = @InstanceStageId AND ApprovalRuleId = @ApprovalRuleId AND Status <> 'Cancelled';

        -- A Group rule with RequiredCount=N fans out one task per member
        -- (wf_CreateTasksForStage) and is satisfied by any N of them; N at or
        -- above the member count means all of them.
        SELECT @RequiredForRule = CASE
            WHEN ApproverType = 'Group' AND RequiredCount > 1 AND RequiredCount < @TotalForRule THEN RequiredCount
            ELSE @TotalForRule END
        FROM dbo.wf_ApprovalRule WHERE ApprovalRuleId = @ApprovalRuleId;

        IF @ApprovedForRule >= @RequiredForRule
        BEGIN
            -- Quorum reached: the remaining members' tasks are no longer needed.
            UPDATE dbo.wf_ApprovalTask SET Status = 'Cancelled'
            WHERE InstanceStageId = @InstanceStageId AND ApprovalRuleId = @ApprovalRuleId AND Status = 'Pending';

            DECLARE @TotalRulesForStage INT, @SatisfiedRulesForStage INT;
            SELECT @TotalRulesForStage = COUNT(*) FROM dbo.wf_ApprovalRule WHERE StageId = @StageId;

            SELECT @SatisfiedRulesForStage = COUNT(DISTINCT ar.ApprovalRuleId)
            FROM dbo.wf_ApprovalRule ar
            WHERE ar.StageId = @StageId
              AND NOT EXISTS (
                  SELECT 1 FROM dbo.wf_ApprovalTask t2
                  WHERE t2.InstanceStageId = @InstanceStageId AND t2.ApprovalRuleId = ar.ApprovalRuleId
                    AND t2.Status NOT IN ('Approved', 'Cancelled')
              );

            IF @SatisfiedRulesForStage >= @TotalRulesForStage
            BEGIN
                UPDATE dbo.wf_WorkflowInstanceStage SET Status = 'Approved', ExitedAt = SYSUTCDATETIME() WHERE InstanceStageId = @InstanceStageId;

                DECLARE @BranchParallelGroupId INT;
                SELECT @BranchParallelGroupId = ParallelGroupId FROM dbo.wf_Stage WHERE StageId = @StageId AND StageType = 'Approval';

                IF @BranchParallelGroupId IS NOT NULL
                BEGIN
                    DECLARE @GroupCompleted BIT, @ContainerStageId INT;
                    EXEC dbo.wf_TryCompleteParallelGroup
                        @ParallelGroupId = @BranchParallelGroupId,
                        @WorkflowInstanceId = @WorkflowInstanceId,
                        @ActorUserId = @ActorUserId,
                        @Completed = @GroupCompleted OUTPUT,
                        @ContainerStageId = @ContainerStageId OUTPUT;

                    IF @GroupCompleted = 1
                    BEGIN
                        SET @NeedsRouting = 1;
                        SET @RoutingFromStageId = @ContainerStageId;
                    END
                END
                ELSE
                BEGIN
                    SET @NeedsRouting = 1;
                    SET @RoutingFromStageId = @StageId;
                    SELECT @ResumeToStageId = ReturnedFromStageId FROM dbo.wf_WorkflowInstanceStage WHERE InstanceStageId = @InstanceStageId;
                END
            END
        END
    END
    ELSE
    BEGIN
        ROLLBACK TRAN;
        THROW 51014, 'Unknown action. Expected Approve, Reject, or Return.', 1;
    END

    COMMIT TRAN;
END
GO
