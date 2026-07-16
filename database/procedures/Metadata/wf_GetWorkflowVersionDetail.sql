-- Composite read for the admin designer UI: everything needed to render
-- and edit one workflow version, as a batch of result sets.
CREATE OR ALTER PROCEDURE dbo.wf_GetWorkflowVersionDetail
    @WorkflowVersionId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT * FROM dbo.wf_WorkflowVersion WHERE WorkflowVersionId = @WorkflowVersionId;
    SELECT * FROM dbo.wf_Stage WHERE WorkflowVersionId = @WorkflowVersionId ORDER BY StageOrder;
    SELECT * FROM dbo.wf_Transition WHERE WorkflowVersionId = @WorkflowVersionId ORDER BY FromStageId, Priority;
    SELECT * FROM dbo.wf_ParallelGroup WHERE WorkflowVersionId = @WorkflowVersionId;

    SELECT r.*
    FROM dbo.wf_ApprovalRule r
    INNER JOIN dbo.wf_Stage s ON s.StageId = r.StageId
    WHERE s.WorkflowVersionId = @WorkflowVersionId;

    SELECT rr.*
    FROM dbo.wf_ReturnRule rr
    INNER JOIN dbo.wf_Stage s ON s.StageId = rr.FromStageId
    WHERE s.WorkflowVersionId = @WorkflowVersionId;

    SELECT * FROM dbo.wf_ApprovalGroup;
    SELECT * FROM dbo.wf_ApprovalGroupMember;
END
GO
