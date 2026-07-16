CREATE OR ALTER PROCEDURE dbo.wf_GetWorkflowInstanceStatus
    @WorkflowInstanceId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        wi.WorkflowInstanceId, wi.Status, wi.BusinessEntityType, wi.BusinessEntityId,
        wi.ContextDataJson, wi.StartedByUserId, wi.StartedAt, wi.CompletedAt,
        cs.StageId AS CurrentStageId, cs.StageKey AS CurrentStageKey, cs.Name AS CurrentStageName,
        d.Code AS WorkflowDefinitionCode, d.Name AS WorkflowDefinitionName, v.VersionNumber
    FROM dbo.wf_WorkflowInstance wi
    LEFT JOIN dbo.wf_Stage cs ON cs.StageId = wi.CurrentStageId
    INNER JOIN dbo.wf_WorkflowVersion v ON v.WorkflowVersionId = wi.WorkflowVersionId
    INNER JOIN dbo.wf_WorkflowDefinition d ON d.WorkflowDefinitionId = v.WorkflowDefinitionId
    WHERE wi.WorkflowInstanceId = @WorkflowInstanceId;

    SELECT t.ApprovalTaskId, t.Status, t.AssignedToUserId, t.AssignedToRoleCode, t.AssignedToGroupId, s.Name AS StageName
    FROM dbo.wf_ApprovalTask t
    INNER JOIN dbo.wf_WorkflowInstanceStage wis ON wis.InstanceStageId = t.InstanceStageId
    INNER JOIN dbo.wf_Stage s ON s.StageId = wis.StageId
    WHERE t.WorkflowInstanceId = @WorkflowInstanceId AND t.Status = 'Pending';
END
GO
