-- Sample business module procedures, mirroring pr_* for PurchaseRequest.
-- The API layer orchestrates create -> start workflow instance -> link.

CREATE OR ALTER PROCEDURE dbo.lc_CreateLeasingCommission
    @RequestedByUserId   UNIQUEIDENTIFIER,
    @LesseeName          NVARCHAR(200),
    @CommissionAmount    DECIMAL(18,2),
    @Branch              NVARCHAR(100),
    @Notes               NVARCHAR(MAX) = NULL,
    @LeasingCommissionId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.LeasingCommission (RequestedByUserId, LesseeName, CommissionAmount, Branch, Notes)
    VALUES (@RequestedByUserId, @LesseeName, @CommissionAmount, @Branch, @Notes);

    SET @LeasingCommissionId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.lc_SetWorkflowInstance
    @LeasingCommissionId INT,
    @WorkflowInstanceId  UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.LeasingCommission SET WorkflowInstanceId = @WorkflowInstanceId WHERE LeasingCommissionId = @LeasingCommissionId;
END
GO

CREATE OR ALTER PROCEDURE dbo.lc_GetLeasingCommission
    @LeasingCommissionId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        lc.LeasingCommissionId, lc.WorkflowInstanceId, lc.RequestedByUserId, lc.LesseeName,
        lc.CommissionAmount, lc.Branch, lc.Notes, lc.CreatedAt,
        wi.Status AS WorkflowStatus, s.Name AS CurrentStageName
    FROM dbo.LeasingCommission lc
    LEFT JOIN dbo.wf_WorkflowInstance wi ON wi.WorkflowInstanceId = lc.WorkflowInstanceId
    LEFT JOIN dbo.wf_Stage s ON s.StageId = wi.CurrentStageId
    WHERE lc.LeasingCommissionId = @LeasingCommissionId;
END
GO

CREATE OR ALTER PROCEDURE dbo.lc_GetMyLeasingCommissions
    @RequestedByUserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        lc.LeasingCommissionId, lc.WorkflowInstanceId, lc.RequestedByUserId, lc.LesseeName,
        lc.CommissionAmount, lc.Branch, lc.Notes, lc.CreatedAt,
        wi.Status AS WorkflowStatus, s.Name AS CurrentStageName
    FROM dbo.LeasingCommission lc
    LEFT JOIN dbo.wf_WorkflowInstance wi ON wi.WorkflowInstanceId = lc.WorkflowInstanceId
    LEFT JOIN dbo.wf_Stage s ON s.StageId = wi.CurrentStageId
    WHERE lc.RequestedByUserId = @RequestedByUserId
    ORDER BY lc.CreatedAt DESC;
END
GO
