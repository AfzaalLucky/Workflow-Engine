-- Generic instance search: every filter is optional. Lets any host app
-- answer "what's the workflow state of my entity X?" or "what have I
-- submitted?" without writing its own join against wf_* tables.
CREATE OR ALTER PROCEDURE dbo.wf_GetWorkflowInstances
    @BusinessEntityType     VARCHAR(100)     = NULL,
    @BusinessEntityId       NVARCHAR(100)    = NULL,
    @WorkflowDefinitionCode VARCHAR(50)      = NULL,
    @StartedByUserId        UNIQUEIDENTIFIER = NULL,
    @Status                 VARCHAR(20)      = NULL,
    @Top                    INT              = 200
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@Top)
        wi.WorkflowInstanceId, wi.WorkflowVersionId, wi.Status, wi.BusinessEntityType, wi.BusinessEntityId,
        wi.ContextDataJson, wi.StartedByUserId, wi.StartedAt, wi.CompletedAt,
        cs.StageId AS CurrentStageId, cs.StageKey AS CurrentStageKey, cs.Name AS CurrentStageName,
        cs.ExternalStatusCode AS CurrentExternalStatusCode,
        d.Code AS WorkflowDefinitionCode, d.Name AS WorkflowDefinitionName, v.VersionNumber
    FROM dbo.wf_WorkflowInstance wi
    LEFT JOIN dbo.wf_Stage cs ON cs.StageId = wi.CurrentStageId
    INNER JOIN dbo.wf_WorkflowVersion v ON v.WorkflowVersionId = wi.WorkflowVersionId
    INNER JOIN dbo.wf_WorkflowDefinition d ON d.WorkflowDefinitionId = v.WorkflowDefinitionId
    WHERE (@BusinessEntityType IS NULL OR wi.BusinessEntityType = @BusinessEntityType)
      AND (@BusinessEntityId IS NULL OR wi.BusinessEntityId = @BusinessEntityId)
      AND (@WorkflowDefinitionCode IS NULL OR d.Code = @WorkflowDefinitionCode)
      AND (@StartedByUserId IS NULL OR wi.StartedByUserId = @StartedByUserId)
      AND (@Status IS NULL OR wi.Status = @Status)
    ORDER BY wi.StartedAt DESC
    OPTION (RECOMPILE);
END
GO
