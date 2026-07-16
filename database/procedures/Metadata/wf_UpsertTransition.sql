CREATE OR ALTER PROCEDURE dbo.wf_UpsertTransition
    @TransitionId        INT = NULL,
    @WorkflowVersionId   INT,
    @FromStageId         INT,
    @ToStageId           INT,
    @ConditionExpression NVARCHAR(500) = NULL,
    @Priority            INT = 100,
    @IsDefault           BIT = 0,
    @ActorUserId         UNIQUEIDENTIFIER,
    @ResultTransitionId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @TransitionId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE TransitionId = @TransitionId)
    BEGIN
        UPDATE dbo.wf_Transition
        SET FromStageId = @FromStageId, ToStageId = @ToStageId, ConditionExpression = @ConditionExpression,
            Priority = @Priority, IsDefault = @IsDefault
        WHERE TransitionId = @TransitionId;
        SET @ResultTransitionId = @TransitionId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, ConditionExpression, Priority, IsDefault)
        VALUES (@WorkflowVersionId, @FromStageId, @ToStageId, @ConditionExpression, @Priority, @IsDefault);
        SET @ResultTransitionId = SCOPE_IDENTITY();
    END

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId)
    VALUES ('Transition', CAST(@ResultTransitionId AS NVARCHAR(20)), 'Upsert', @ActorUserId);
END
GO
