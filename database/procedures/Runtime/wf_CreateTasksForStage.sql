-- Internal helper: resolves the ApprovalRule(s) for a stage into concrete
-- ApprovalTask rows for one stage visit (InstanceStageId).
CREATE OR ALTER PROCEDURE dbo.wf_CreateTasksForStage
    @InstanceStageId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StageId INT, @WorkflowInstanceId UNIQUEIDENTIFIER;
    SELECT @StageId = StageId, @WorkflowInstanceId = WorkflowInstanceId
    FROM dbo.wf_WorkflowInstanceStage WHERE InstanceStageId = @InstanceStageId;

    DECLARE @ApprovalRuleId INT, @ApproverType VARCHAR(10), @SpecificUserId UNIQUEIDENTIFIER,
            @ApproverRoleCode VARCHAR(50), @ApprovalGroupId INT, @RequiredCount INT;

    DECLARE ruleCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT ApprovalRuleId, ApproverType, SpecificUserId, ApproverRoleCode, ApprovalGroupId, RequiredCount
        FROM dbo.wf_ApprovalRule WHERE StageId = @StageId;

    OPEN ruleCursor;
    FETCH NEXT FROM ruleCursor INTO @ApprovalRuleId, @ApproverType, @SpecificUserId, @ApproverRoleCode, @ApprovalGroupId, @RequiredCount;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @ApproverType = 'User'
        BEGIN
            INSERT INTO dbo.wf_ApprovalTask (InstanceStageId, WorkflowInstanceId, ApprovalRuleId, AssignedToUserId)
            VALUES (@InstanceStageId, @WorkflowInstanceId, @ApprovalRuleId, @SpecificUserId);
        END
        ELSE IF @ApproverType = 'Role'
        BEGIN
            INSERT INTO dbo.wf_ApprovalTask (InstanceStageId, WorkflowInstanceId, ApprovalRuleId, AssignedToRoleCode)
            VALUES (@InstanceStageId, @WorkflowInstanceId, @ApprovalRuleId, @ApproverRoleCode);
        END
        ELSE IF @ApproverType = 'Group'
        BEGIN
            IF @RequiredCount <= 1
            BEGIN
                -- Any-one-of: a single task, claimable by any active member (user or role match).
                INSERT INTO dbo.wf_ApprovalTask (InstanceStageId, WorkflowInstanceId, ApprovalRuleId, AssignedToGroupId)
                VALUES (@InstanceStageId, @WorkflowInstanceId, @ApprovalRuleId, @ApprovalGroupId);
            END
            ELSE
            BEGIN
                -- All-of: one task per explicit user member. Role-based membership
                -- can't be enumerated to specific users without a user directory,
                -- so all-of groups must be composed of explicit User members.
                INSERT INTO dbo.wf_ApprovalTask (InstanceStageId, WorkflowInstanceId, ApprovalRuleId, AssignedToUserId, AssignedToGroupId)
                SELECT @InstanceStageId, @WorkflowInstanceId, @ApprovalRuleId, m.UserId, @ApprovalGroupId
                FROM dbo.wf_ApprovalGroupMember m
                WHERE m.ApprovalGroupId = @ApprovalGroupId AND m.MemberType = 'User' AND m.IsActive = 1;
            END
        END

        FETCH NEXT FROM ruleCursor INTO @ApprovalRuleId, @ApproverType, @SpecificUserId, @ApproverRoleCode, @ApprovalGroupId, @RequiredCount;
    END

    CLOSE ruleCursor;
    DEALLOCATE ruleCursor;
END
GO
