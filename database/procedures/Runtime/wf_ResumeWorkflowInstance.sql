-- Resumes a Returned (requester resubmitting after rework) or Errored
-- (admin recovery) instance. If the current stage still has an approver
-- (e.g. it was resumed in place), reopens tasks there; otherwise (e.g.
-- resuming at a Start stage with no approver) signals the caller to
-- resolve routing and call wf_AdvanceToStage.
CREATE OR ALTER PROCEDURE dbo.wf_ResumeWorkflowInstance
    @WorkflowInstanceId      UNIQUEIDENTIFIER,
    @ActorUserId             UNIQUEIDENTIFIER,
    @UpdatedContextDataJson  NVARCHAR(MAX) = NULL,
    @CurrentStageId          INT OUTPUT,
    @NeedsRouting            BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @NeedsRouting = 0;

    DECLARE @Status VARCHAR(20);
    SELECT @Status = Status, @CurrentStageId = CurrentStageId
    FROM dbo.wf_WorkflowInstance WHERE WorkflowInstanceId = @WorkflowInstanceId;

    IF @Status NOT IN ('Returned', 'Errored')
        THROW 51020, 'Workflow instance is not in a resumable state.', 1;

    BEGIN TRAN;

    IF @UpdatedContextDataJson IS NOT NULL
        UPDATE dbo.wf_WorkflowInstance SET ContextDataJson = @UpdatedContextDataJson WHERE WorkflowInstanceId = @WorkflowInstanceId;

    UPDATE dbo.wf_WorkflowInstance SET Status = 'InProgress' WHERE WorkflowInstanceId = @WorkflowInstanceId;

    DECLARE @InstanceStageId BIGINT, @HasRules BIT;
    SELECT TOP 1 @InstanceStageId = InstanceStageId
    FROM dbo.wf_WorkflowInstanceStage
    WHERE WorkflowInstanceId = @WorkflowInstanceId AND StageId = @CurrentStageId AND Status = 'Active'
    ORDER BY InstanceStageId DESC;

    SET @HasRules = CASE WHEN EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @CurrentStageId) THEN 1 ELSE 0 END;

    INSERT INTO dbo.wf_ApprovalAction (WorkflowInstanceId, InstanceStageId, ActionType, ActorUserId, OldStatus, NewStatus, NewStageId)
    VALUES (@WorkflowInstanceId, @InstanceStageId, 'Resume', @ActorUserId, @Status, 'InProgress', @CurrentStageId);

    IF @HasRules = 1
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalTask WHERE InstanceStageId = @InstanceStageId AND Status = 'Pending')
            EXEC dbo.wf_CreateTasksForStage @InstanceStageId = @InstanceStageId;
    END
    ELSE
    BEGIN
        SET @NeedsRouting = 1;
    END

    COMMIT TRAN;
END
GO
