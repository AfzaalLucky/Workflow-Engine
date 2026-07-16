CREATE OR ALTER PROCEDURE dbo.wf_UpsertWorkflowDefinition
    @Code                 VARCHAR(50),
    @Name                 NVARCHAR(200),
    @Description          NVARCHAR(500) = NULL,
    @IsActive             BIT = 1,
    @ActorUserId          UNIQUEIDENTIFIER,
    @WorkflowDefinitionId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @WorkflowDefinitionId = WorkflowDefinitionId FROM dbo.wf_WorkflowDefinition WHERE Code = @Code;

    IF @WorkflowDefinitionId IS NULL
    BEGIN
        INSERT INTO dbo.wf_WorkflowDefinition (Code, Name, Description, IsActive, CreatedByUserId)
        VALUES (@Code, @Name, @Description, @IsActive, @ActorUserId);
        SET @WorkflowDefinitionId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.wf_WorkflowDefinition
        SET Name = @Name, Description = @Description, IsActive = @IsActive
        WHERE WorkflowDefinitionId = @WorkflowDefinitionId;
    END

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId, DetailJson)
    VALUES ('WorkflowDefinition', CAST(@WorkflowDefinitionId AS NVARCHAR(20)), 'Upsert', @ActorUserId,
            (SELECT @Code AS Code, @Name AS Name FOR JSON PATH, WITHOUT_ARRAY_WRAPPER));
END
GO
