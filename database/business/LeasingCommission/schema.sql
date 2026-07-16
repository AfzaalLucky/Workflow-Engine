-- =============================================================
-- Sample business module: Leasing Commission. Ordinary application
-- schema, not part of the generic engine -- points at the engine only
-- via WorkflowInstanceId. See LeasingFlow.md for the source rules and
-- database/seed/seed_leasing_commission_workflow.sql for how they map
-- onto wf_* metadata.
-- =============================================================

CREATE TABLE dbo.LeasingCommission (
    LeasingCommissionId INT IDENTITY(1,1) NOT NULL,
    WorkflowInstanceId  UNIQUEIDENTIFIER NULL,
    RequestedByUserId   UNIQUEIDENTIFIER NOT NULL,
    LesseeName          NVARCHAR(200)    NOT NULL,
    CommissionAmount    DECIMAL(18,2)    NOT NULL,
    Branch              NVARCHAR(100)    NOT NULL,
    Notes               NVARCHAR(MAX)    NULL,
    CreatedAt           DATETIME2(3)     NOT NULL CONSTRAINT DF_LeasingCommission_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_LeasingCommission PRIMARY KEY CLUSTERED (LeasingCommissionId),
    CONSTRAINT FK_LeasingCommission_WorkflowInstance FOREIGN KEY (WorkflowInstanceId)
        REFERENCES dbo.wf_WorkflowInstance (WorkflowInstanceId)
);
GO

CREATE NONCLUSTERED INDEX IX_LeasingCommission_RequestedBy ON dbo.LeasingCommission (RequestedByUserId);
CREATE NONCLUSTERED INDEX IX_LeasingCommission_WorkflowInstance ON dbo.LeasingCommission (WorkflowInstanceId);
GO
