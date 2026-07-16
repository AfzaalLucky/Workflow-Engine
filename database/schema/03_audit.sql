-- =============================================================
-- Generic Workflow Engine - Metadata Audit
-- Tracks admin changes to workflow definitions (who published a
-- version, edited a rule, etc). Distinct from wf_ApprovalAction,
-- which audits runtime approval activity, not metadata edits.
-- =============================================================

CREATE TABLE dbo.wf_AuditLog (
    AuditLogId            BIGINT IDENTITY(1,1) NOT NULL,
    EntityType            VARCHAR(100)     NOT NULL,
    EntityId              NVARCHAR(100)    NOT NULL,
    Action                VARCHAR(50)      NOT NULL,
    ActorUserId           UNIQUEIDENTIFIER NOT NULL,
    ActionAt              DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_AuditLog_ActionAt DEFAULT (SYSUTCDATETIME()),
    DetailJson            NVARCHAR(MAX)    NULL,
    CONSTRAINT PK_wf_AuditLog PRIMARY KEY CLUSTERED (AuditLogId)
);
GO

CREATE NONCLUSTERED INDEX IX_wf_AuditLog_Entity ON dbo.wf_AuditLog (EntityType, EntityId, ActionAt);
GO
