-- Full audit trail for one instance: every action, actor, and old/new state.
CREATE OR ALTER PROCEDURE dbo.wf_GetWorkflowInstanceHistory
    @WorkflowInstanceId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        a.ApprovalActionId, a.ActionType, a.ActorUserId, a.ActionAt, a.Comments,
        a.OldStatus, a.NewStatus,
        os.Name AS OldStageName, ns.Name AS NewStageName,
        u.DisplayName AS ActorDisplayName
    FROM dbo.wf_ApprovalAction a
    LEFT JOIN dbo.wf_Stage os ON os.StageId = a.OldStageId
    LEFT JOIN dbo.wf_Stage ns ON ns.StageId = a.NewStageId
    LEFT JOIN dbo.wf_UserRef u ON u.UserId = a.ActorUserId
    WHERE a.WorkflowInstanceId = @WorkflowInstanceId
    ORDER BY a.ActionAt, a.ApprovalActionId;
END
GO
