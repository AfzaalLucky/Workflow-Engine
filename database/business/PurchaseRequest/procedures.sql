-- Sample business module procedures. Note these call no wf_* engine
-- procedures directly for state changes -- the API layer orchestrates
-- (create request -> start workflow instance -> link the two), keeping
-- the engine and the business module decoupled.

CREATE OR ALTER PROCEDURE dbo.pr_CreatePurchaseRequest
    @RequestedByUserId  UNIQUEIDENTIFIER,
    @Title              NVARCHAR(200),
    @Description        NVARCHAR(MAX) = NULL,
    @Amount             DECIMAL(18,2),
    @Department         NVARCHAR(100),
    @PurchaseRequestId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.PurchaseRequest (RequestedByUserId, Title, Description, Amount, Department)
    VALUES (@RequestedByUserId, @Title, @Description, @Amount, @Department);

    SET @PurchaseRequestId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.pr_SetWorkflowInstance
    @PurchaseRequestId  INT,
    @WorkflowInstanceId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.PurchaseRequest SET WorkflowInstanceId = @WorkflowInstanceId WHERE PurchaseRequestId = @PurchaseRequestId;
END
GO

CREATE OR ALTER PROCEDURE dbo.pr_GetPurchaseRequest
    @PurchaseRequestId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pr.PurchaseRequestId, pr.WorkflowInstanceId, pr.RequestedByUserId, pr.Title,
        pr.Description, pr.Amount, pr.Department, pr.CreatedAt,
        wi.Status AS WorkflowStatus, s.Name AS CurrentStageName
    FROM dbo.PurchaseRequest pr
    LEFT JOIN dbo.wf_WorkflowInstance wi ON wi.WorkflowInstanceId = pr.WorkflowInstanceId
    LEFT JOIN dbo.wf_Stage s ON s.StageId = wi.CurrentStageId
    WHERE pr.PurchaseRequestId = @PurchaseRequestId;
END
GO

CREATE OR ALTER PROCEDURE dbo.pr_GetMyPurchaseRequests
    @RequestedByUserId UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pr.PurchaseRequestId, pr.WorkflowInstanceId, pr.RequestedByUserId, pr.Title,
        pr.Description, pr.Amount, pr.Department, pr.CreatedAt,
        wi.Status AS WorkflowStatus, s.Name AS CurrentStageName
    FROM dbo.PurchaseRequest pr
    LEFT JOIN dbo.wf_WorkflowInstance wi ON wi.WorkflowInstanceId = pr.WorkflowInstanceId
    LEFT JOIN dbo.wf_Stage s ON s.StageId = wi.CurrentStageId
    WHERE pr.RequestedByUserId = @RequestedByUserId
    ORDER BY pr.CreatedAt DESC;
END
GO
