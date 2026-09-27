-- Called by the .NET layer when routing fails after a stage has already
-- been satisfied (no transition condition matched, a bad NCalc expression,
-- etc). Without this the instance would sit InProgress with no active
-- stage and no pending tasks -- invisible and stuck. Errored instances are
-- listed via wf_GetWorkflowInstances and recovered with
-- wf_ResumeWorkflowInstance once the metadata is fixed.
CREATE OR ALTER PROCEDURE dbo.wf_MarkInstanceErrored
    @WorkflowInstanceId UNIQUEIDENTIFIER,
    @ActorUserId        UNIQUEIDENTIFIER,
    @ErrorMessage       NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN;

    DECLARE @OldStatus VARCHAR(20), @CurrentStageId INT;
    SELECT @OldStatus = Status, @CurrentStageId = CurrentStageId
    FROM dbo.wf_WorkflowInstance WITH (UPDLOCK, ROWLOCK)
    WHERE WorkflowInstanceId = @WorkflowInstanceId;

    IF @OldStatus IS NULL OR @OldStatus <> 'InProgress'
    BEGIN
        COMMIT TRAN;
        RETURN;
    END

    DECLARE @InstanceStageId BIGINT;
    SELECT TOP 1 @InstanceStageId = InstanceStageId
    FROM dbo.wf_WorkflowInstanceStage
    WHERE WorkflowInstanceId = @WorkflowInstanceId
    ORDER BY InstanceStageId DESC;

    UPDATE dbo.wf_WorkflowInstance SET Status = 'Errored' WHERE WorkflowInstanceId = @WorkflowInstanceId;

    INSERT INTO dbo.wf_ApprovalAction (WorkflowInstanceId, InstanceStageId, ActionType, ActorUserId, OldStatus, NewStatus, OldStageId, Comments)
    VALUES (@WorkflowInstanceId, @InstanceStageId, 'Error', @ActorUserId, @OldStatus, 'Errored', @CurrentStageId, @ErrorMessage);

    EXEC dbo.wf_EnqueueEvent @WorkflowInstanceId = @WorkflowInstanceId, @EventType = 'InstanceErrored',
        @ActorUserId = @ActorUserId, @Comments = @ErrorMessage;

    COMMIT TRAN;
END
GO
