CREATE OR ALTER PROCEDURE dbo.wf_GetTaskDetail
    @ApprovalTaskId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.*, s.StageKey, s.Name AS StageName, s.StageType,
        wi.BusinessEntityType, wi.BusinessEntityId, wi.ContextDataJson, wi.Status AS InstanceStatus,
        d.Code AS WorkflowDefinitionCode, d.Name AS WorkflowDefinitionName
    FROM dbo.wf_ApprovalTask t
    INNER JOIN dbo.wf_WorkflowInstanceStage wis ON wis.InstanceStageId = t.InstanceStageId
    INNER JOIN dbo.wf_Stage s ON s.StageId = wis.StageId
    INNER JOIN dbo.wf_WorkflowInstance wi ON wi.WorkflowInstanceId = t.WorkflowInstanceId
    INNER JOIN dbo.wf_WorkflowVersion v ON v.WorkflowVersionId = wi.WorkflowVersionId
    INNER JOIN dbo.wf_WorkflowDefinition d ON d.WorkflowDefinitionId = v.WorkflowDefinitionId
    WHERE t.ApprovalTaskId = @ApprovalTaskId;

    -- Legal return targets for this task's stage, so the UI can offer a
    -- "Return to..." choice when more than one applies.
    SELECT rr.FromStageId, rr.ToStageId, s.Name AS ToStageName, rr.RequireComment
    FROM dbo.wf_ApprovalTask t
    INNER JOIN dbo.wf_WorkflowInstanceStage wis ON wis.InstanceStageId = t.InstanceStageId
    INNER JOIN dbo.wf_ReturnRule rr ON rr.FromStageId = wis.StageId
    INNER JOIN dbo.wf_Stage s ON s.StageId = rr.ToStageId
    WHERE t.ApprovalTaskId = @ApprovalTaskId;
END
GO
