-- Inbox query: tasks assigned directly to the user, matching one of the
-- user's role claims, or belonging to a group the user is an eligible
-- member of (by explicit user membership or by role membership).
CREATE OR ALTER PROCEDURE dbo.wf_GetMyPendingTasks
    @UserId     UNIQUEIDENTIFIER,
    @RoleCodes  dbo.wf_RoleCodeList READONLY
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.ApprovalTaskId, t.InstanceStageId, t.WorkflowInstanceId, t.ApprovalRuleId,
        t.AssignedToUserId, t.AssignedToRoleCode, t.AssignedToGroupId,
        t.Status, t.CompletedByUserId, t.Comments, t.CreatedAt, t.CompletedAt,
        s.StageKey, s.Name AS StageName, s.StageType,
        wi.BusinessEntityType, wi.BusinessEntityId, wi.ContextDataJson,
        d.Code AS WorkflowDefinitionCode, d.Name AS WorkflowDefinitionName
    FROM dbo.wf_ApprovalTask t
    INNER JOIN dbo.wf_WorkflowInstanceStage wis ON wis.InstanceStageId = t.InstanceStageId
    INNER JOIN dbo.wf_Stage s ON s.StageId = wis.StageId
    INNER JOIN dbo.wf_WorkflowInstance wi ON wi.WorkflowInstanceId = t.WorkflowInstanceId
    INNER JOIN dbo.wf_WorkflowVersion v ON v.WorkflowVersionId = wi.WorkflowVersionId
    INNER JOIN dbo.wf_WorkflowDefinition d ON d.WorkflowDefinitionId = v.WorkflowDefinitionId
    WHERE t.Status = 'Pending'
      AND (
          t.AssignedToUserId = @UserId
          OR (t.AssignedToRoleCode IS NOT NULL AND EXISTS (SELECT 1 FROM @RoleCodes r WHERE r.RoleCode = t.AssignedToRoleCode))
          OR (t.AssignedToGroupId IS NOT NULL AND (
                EXISTS (SELECT 1 FROM dbo.wf_ApprovalGroupMember m WHERE m.ApprovalGroupId = t.AssignedToGroupId AND m.MemberType = 'User' AND m.UserId = @UserId AND m.IsActive = 1)
                OR EXISTS (SELECT 1 FROM dbo.wf_ApprovalGroupMember m INNER JOIN @RoleCodes r ON r.RoleCode = m.RoleCode WHERE m.ApprovalGroupId = t.AssignedToGroupId AND m.MemberType = 'Role' AND m.IsActive = 1)
          ))
      )
    ORDER BY t.CreatedAt;
END
GO
