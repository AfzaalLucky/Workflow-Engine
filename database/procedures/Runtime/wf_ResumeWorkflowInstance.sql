-- Resumes a Returned (requester resubmitting after rework) or Errored
-- (admin recovery) instance.
--
-- Returned: if the current stage still has an approver, reopens tasks
-- there; otherwise (e.g. resuming at a Start stage with no approver)
-- signals the caller to route onward. If the return was ReturnToOrigin,
-- @ResumeToStageId names the stage to jump straight back to.
--
-- Errored: routing failed after the current stage was already satisfied,
-- so the stage is never reopened -- the caller simply re-runs routing
-- (typically after an admin fixed the transition metadata).
CREATE OR ALTER PROCEDURE dbo.wf_ResumeWorkflowInstance
    @WorkflowInstanceId      UNIQUEIDENTIFIER,
    @ActorUserId             UNIQUEIDENTIFIER,
    @UpdatedContextDataJson  NVARCHAR(MAX) = NULL,
    @CurrentStageId          INT OUTPUT,
    @NeedsRouting            BIT OUTPUT,
    @ResumeToStageId         INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @NeedsRouting = 0;
    SET @ResumeToStageId = NULL;

    BEGIN TRAN;

    DECLARE @Status VARCHAR(20);
    SELECT @Status = Status, @CurrentStageId = CurrentStageId
    FROM dbo.wf_WorkflowInstance WITH (UPDLOCK, ROWLOCK)
    WHERE WorkflowInstanceId = @WorkflowInstanceId;

    IF @Status IS NULL OR @Status NOT IN ('Returned', 'Errored')
    BEGIN
        ROLLBACK TRAN;
        THROW 51020, 'Workflow instance is not in a resumable state.', 1;
    END

    IF @UpdatedContextDataJson IS NOT NULL
        UPDATE dbo.wf_WorkflowInstance SET ContextDataJson = @UpdatedContextDataJson WHERE WorkflowInstanceId = @WorkflowInstanceId;

    UPDATE dbo.wf_WorkflowInstance SET Status = 'InProgress' WHERE WorkflowInstanceId = @WorkflowInstanceId;

    -- Prefer the active visit of the current stage; an Errored instance may
    -- have none (its stage was already approved), so fall back to the latest.
    DECLARE @InstanceStageId BIGINT, @VisitStatus VARCHAR(20), @ReturnedFromStageId INT, @HasRules BIT;
    SELECT TOP 1 @InstanceStageId = InstanceStageId, @VisitStatus = Status, @ReturnedFromStageId = ReturnedFromStageId
    FROM dbo.wf_WorkflowInstanceStage
    WHERE WorkflowInstanceId = @WorkflowInstanceId AND StageId = @CurrentStageId
    ORDER BY CASE WHEN Status = 'Active' THEN 0 ELSE 1 END, InstanceStageId DESC;

    SET @HasRules = CASE WHEN EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @CurrentStageId) THEN 1 ELSE 0 END;

    INSERT INTO dbo.wf_ApprovalAction (WorkflowInstanceId, InstanceStageId, ActionType, ActorUserId, OldStatus, NewStatus, NewStageId)
    VALUES (@WorkflowInstanceId, @InstanceStageId, 'Resume', @ActorUserId, @Status, 'InProgress', @CurrentStageId);

    IF @Status = 'Returned' AND @HasRules = 1 AND @VisitStatus = 'Active'
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalTask WHERE InstanceStageId = @InstanceStageId AND Status = 'Pending')
            EXEC dbo.wf_CreateTasksForStage @InstanceStageId = @InstanceStageId;
    END
    ELSE
    BEGIN
        SET @NeedsRouting = 1;
        SET @ResumeToStageId = @ReturnedFromStageId;
    END

    EXEC dbo.wf_EnqueueEvent @WorkflowInstanceId = @WorkflowInstanceId, @EventType = 'InstanceResumed', @ActorUserId = @ActorUserId;

    COMMIT TRAN;
END
GO
