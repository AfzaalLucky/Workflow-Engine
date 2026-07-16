-- Flips any currently Published version of the same definition to Retired,
-- so running instances stay pinned to the version they started on while new
-- instances pick up the newly published one.
CREATE OR ALTER PROCEDURE dbo.wf_PublishWorkflowVersion
    @WorkflowVersionId INT,
    @ActorUserId       UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @WorkflowDefinitionId INT;

    SELECT @WorkflowDefinitionId = WorkflowDefinitionId FROM dbo.wf_WorkflowVersion WHERE WorkflowVersionId = @WorkflowVersionId;
    IF @WorkflowDefinitionId IS NULL
        THROW 51000, 'Workflow version not found.', 1;

    BEGIN TRAN;

    UPDATE dbo.wf_WorkflowVersion
    SET Status = 'Retired'
    WHERE WorkflowDefinitionId = @WorkflowDefinitionId AND Status = 'Published';

    UPDATE dbo.wf_WorkflowVersion
    SET Status = 'Published', PublishedAt = SYSUTCDATETIME()
    WHERE WorkflowVersionId = @WorkflowVersionId;

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId)
    VALUES ('WorkflowVersion', CAST(@WorkflowVersionId AS NVARCHAR(20)), 'Publish', @ActorUserId);

    COMMIT TRAN;
END
GO
