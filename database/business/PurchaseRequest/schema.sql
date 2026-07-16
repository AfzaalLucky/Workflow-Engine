-- =============================================================
-- Sample business module: Purchase Request. This is ordinary
-- application schema, NOT part of the generic engine -- it only
-- points at the engine via WorkflowInstanceId. Proves the engine
-- can be adopted by a business process without any wf_* changes.
-- =============================================================

CREATE TABLE dbo.PurchaseRequest (
    PurchaseRequestId   INT IDENTITY(1,1) NOT NULL,
    WorkflowInstanceId  UNIQUEIDENTIFIER NULL,
    RequestedByUserId   UNIQUEIDENTIFIER NOT NULL,
    Title               NVARCHAR(200)    NOT NULL,
    Description         NVARCHAR(MAX)    NULL,
    Amount              DECIMAL(18,2)    NOT NULL,
    Department          NVARCHAR(100)    NOT NULL,
    CreatedAt           DATETIME2(3)     NOT NULL CONSTRAINT DF_PurchaseRequest_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_PurchaseRequest PRIMARY KEY CLUSTERED (PurchaseRequestId),
    CONSTRAINT FK_PurchaseRequest_WorkflowInstance FOREIGN KEY (WorkflowInstanceId)
        REFERENCES dbo.wf_WorkflowInstance (WorkflowInstanceId)
);
GO

CREATE NONCLUSTERED INDEX IX_PurchaseRequest_RequestedBy ON dbo.PurchaseRequest (RequestedByUserId);
CREATE NONCLUSTERED INDEX IX_PurchaseRequest_WorkflowInstance ON dbo.PurchaseRequest (WorkflowInstanceId);
GO
