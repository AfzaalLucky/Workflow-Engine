CREATE OR ALTER PROCEDURE dbo.wf_CreateWorkflowVersion
    @WorkflowDefinitionId INT,
    @ActorUserId          UNIQUEIDENTIFIER,
    @WorkflowVersionId    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NextVersion INT;

    SELECT @NextVersion = ISNULL(MAX(VersionNumber), 0) + 1
    FROM dbo.wf_WorkflowVersion WHERE WorkflowDefinitionId = @WorkflowDefinitionId;

    INSERT INTO dbo.wf_WorkflowVersion (WorkflowDefinitionId, VersionNumber, Status, CreatedByUserId)
    VALUES (@WorkflowDefinitionId, @NextVersion, 'Draft', @ActorUserId);

    SET @WorkflowVersionId = SCOPE_IDENTITY();

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId, DetailJson)
    VALUES ('WorkflowVersion', CAST(@WorkflowVersionId AS NVARCHAR(20)), 'Create', @ActorUserId,
            (SELECT @WorkflowDefinitionId AS WorkflowDefinitionId, @NextVersion AS VersionNumber FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
END
GO
