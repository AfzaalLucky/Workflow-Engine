CREATE OR ALTER PROCEDURE dbo.wf_GetWorkflowDefinitions
AS
BEGIN
    SET NOCOUNT ON;

    SELECT d.WorkflowDefinitionId, d.Code, d.Name, d.Description, d.IsActive,
           pv.WorkflowVersionId AS PublishedVersionId, pv.VersionNumber AS PublishedVersionNumber
    FROM dbo.wf_WorkflowDefinition d
    OUTER APPLY (
        SELECT TOP 1 v.WorkflowVersionId, v.VersionNumber
        FROM dbo.wf_WorkflowVersion v
        WHERE v.WorkflowDefinitionId = d.WorkflowDefinitionId AND v.Status = 'Published'
        ORDER BY v.VersionNumber DESC
    ) pv
    ORDER BY d.Name;
END
GO
