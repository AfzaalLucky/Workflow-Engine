-- =============================================================
-- Upgrades an existing WorkflowEngineDb (deployed from the original
-- schema scripts) to the generic-engine schema. Idempotent: safe to
-- re-run. Fresh databases get the same shape from schema/*.sql
-- directly and do not need this file.
--
-- Adds:
--   wf_Stage.ExternalStatusCode           host-app status mapping per stage
--   wf_ReturnRule.ResumeMode              Forward | ReturnToOrigin
--   wf_WorkflowInstanceStage.ReturnedFromStageId
--   wf_ApprovalAction ActionType 'Error'
--   wf_WorkflowEvent                      transactional outbox
-- =============================================================

IF COL_LENGTH('dbo.wf_Stage', 'ExternalStatusCode') IS NULL
    ALTER TABLE dbo.wf_Stage ADD ExternalStatusCode VARCHAR(50) NULL;
GO

IF COL_LENGTH('dbo.wf_ReturnRule', 'ResumeMode') IS NULL
    ALTER TABLE dbo.wf_ReturnRule ADD ResumeMode VARCHAR(20) NOT NULL
        CONSTRAINT DF_wf_ReturnRule_ResumeMode DEFAULT ('Forward') WITH VALUES;
GO

IF OBJECT_ID('dbo.CK_wf_ReturnRule_ResumeMode', 'C') IS NULL
    ALTER TABLE dbo.wf_ReturnRule ADD CONSTRAINT CK_wf_ReturnRule_ResumeMode
        CHECK (ResumeMode IN ('Forward','ReturnToOrigin'));
GO

IF COL_LENGTH('dbo.wf_WorkflowInstanceStage', 'ReturnedFromStageId') IS NULL
BEGIN
    ALTER TABLE dbo.wf_WorkflowInstanceStage ADD ReturnedFromStageId INT NULL;
    ALTER TABLE dbo.wf_WorkflowInstanceStage ADD CONSTRAINT FK_wf_WorkflowInstanceStage_ReturnedFrom
        FOREIGN KEY (ReturnedFromStageId) REFERENCES dbo.wf_Stage (StageId);
END
GO

IF OBJECT_ID('dbo.CK_wf_ApprovalAction_ActionType', 'C') IS NOT NULL
    ALTER TABLE dbo.wf_ApprovalAction DROP CONSTRAINT CK_wf_ApprovalAction_ActionType;
GO
ALTER TABLE dbo.wf_ApprovalAction ADD CONSTRAINT CK_wf_ApprovalAction_ActionType CHECK (
    ActionType IN ('Submit','Approve','Reject','Return','Resume','SystemAdvance','Cancel','Error')
);
GO

IF OBJECT_ID('dbo.wf_WorkflowEvent', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.wf_WorkflowEvent (
        EventId               BIGINT IDENTITY(1,1) NOT NULL,
        WorkflowInstanceId    UNIQUEIDENTIFIER NOT NULL,
        EventType             VARCHAR(50)      NOT NULL,
        PayloadJson           NVARCHAR(MAX)    NOT NULL,
        Status                VARCHAR(20)      NOT NULL CONSTRAINT DF_wf_WorkflowEvent_Status DEFAULT ('Pending'),
        AttemptCount          INT              NOT NULL CONSTRAINT DF_wf_WorkflowEvent_AttemptCount DEFAULT (0),
        NextAttemptAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_WorkflowEvent_NextAttemptAt DEFAULT (SYSUTCDATETIME()),
        LastError             NVARCHAR(2000)   NULL,
        CreatedAt             DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_WorkflowEvent_CreatedAt DEFAULT (SYSUTCDATETIME()),
        DeliveredAt           DATETIME2(3)     NULL,
        CONSTRAINT PK_wf_WorkflowEvent PRIMARY KEY CLUSTERED (EventId),
        CONSTRAINT FK_wf_WorkflowEvent_Instance FOREIGN KEY (WorkflowInstanceId)
            REFERENCES dbo.wf_WorkflowInstance (WorkflowInstanceId),
        CONSTRAINT CK_wf_WorkflowEvent_Status CHECK (Status IN ('Pending','Delivered','Failed'))
    );
    CREATE NONCLUSTERED INDEX IX_wf_WorkflowEvent_Pending ON dbo.wf_WorkflowEvent (Status, NextAttemptAt) INCLUDE (WorkflowInstanceId);
    CREATE NONCLUSTERED INDEX IX_wf_WorkflowEvent_Instance ON dbo.wf_WorkflowEvent (WorkflowInstanceId, Status, EventId);
END
GO

-- Sample module: lets the LeasingCommission status-sync handler mirror the
-- engine's ExternalStatusCode onto the business row.
IF OBJECT_ID('dbo.LeasingCommission', 'U') IS NOT NULL AND COL_LENGTH('dbo.LeasingCommission', 'StatusCode') IS NULL
    ALTER TABLE dbo.LeasingCommission ADD StatusCode VARCHAR(50) NULL;
GO
