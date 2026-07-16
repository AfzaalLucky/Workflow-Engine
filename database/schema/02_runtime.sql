-- =============================================================
-- Generic Workflow Engine - Runtime Schema
-- Instance-time tables: one row set per running/completed workflow.
-- =============================================================

-- WorkflowInstanceId is the correlation key a business table stores as its
-- own FK (e.g. PurchaseRequest.WorkflowInstanceId) -- the engine never
-- needs to know about business tables.
CREATE TABLE dbo.wf_WorkflowInstance (
    WorkflowInstanceId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_wf_WorkflowInstance_Id DEFAULT (NEWID()),
    WorkflowVersionId     INT              NOT NULL,
    BusinessEntityType    VARCHAR(100)     NOT NULL,
    BusinessEntityId      NVARCHAR(100)    NOT NULL,
    CurrentStageId        INT              NULL,
    Status                VARCHAR(20)      NOT NULL CONSTRAINT DF_wf_WorkflowInstance_Status DEFAULT ('InProgress'),
    ContextDataJson       NVARCHAR(MAX)    NULL, -- data used for dynamic routing, e.g. {"Amount":75000,"Department":"IT"}
    StartedByUserId       UNIQUEIDENTIFIER NOT NULL,
    StartedAt             DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_WorkflowInstance_StartedAt DEFAULT (SYSUTCDATETIME()),
    CompletedAt           DATETIME2(3)     NULL,
    CONSTRAINT PK_wf_WorkflowInstance PRIMARY KEY CLUSTERED (WorkflowInstanceId),
    CONSTRAINT FK_wf_WorkflowInstance_Version FOREIGN KEY (WorkflowVersionId)
        REFERENCES dbo.wf_WorkflowVersion (WorkflowVersionId),
    CONSTRAINT FK_wf_WorkflowInstance_CurrentStage FOREIGN KEY (CurrentStageId)
        REFERENCES dbo.wf_Stage (StageId),
    CONSTRAINT CK_wf_WorkflowInstance_Status CHECK (
        Status IN ('InProgress','Approved','Rejected','Returned','Completed','Cancelled','Errored')
    )
);
GO

-- Every visit to a stage for an instance. This ledger (not just
-- WorkflowInstance.CurrentStageId) is what makes exact resume possible:
-- AttemptNumber increments each time a Return->Resume cycle re-enters a stage.
CREATE TABLE dbo.wf_WorkflowInstanceStage (
    InstanceStageId       BIGINT IDENTITY(1,1) NOT NULL,
    WorkflowInstanceId    UNIQUEIDENTIFIER NOT NULL,
    StageId               INT              NOT NULL,
    ParallelGroupId       INT              NULL,
    Status                VARCHAR(20)      NOT NULL CONSTRAINT DF_wf_WorkflowInstanceStage_Status DEFAULT ('Pending'),
    AttemptNumber         INT              NOT NULL CONSTRAINT DF_wf_WorkflowInstanceStage_Attempt DEFAULT (1),
    EnteredAt             DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_WorkflowInstanceStage_EnteredAt DEFAULT (SYSUTCDATETIME()),
    ExitedAt              DATETIME2(3)     NULL,
    CONSTRAINT PK_wf_WorkflowInstanceStage PRIMARY KEY CLUSTERED (InstanceStageId),
    CONSTRAINT FK_wf_WorkflowInstanceStage_Instance FOREIGN KEY (WorkflowInstanceId)
        REFERENCES dbo.wf_WorkflowInstance (WorkflowInstanceId),
    CONSTRAINT FK_wf_WorkflowInstanceStage_Stage FOREIGN KEY (StageId) REFERENCES dbo.wf_Stage (StageId),
    CONSTRAINT FK_wf_WorkflowInstanceStage_ParallelGroup FOREIGN KEY (ParallelGroupId)
        REFERENCES dbo.wf_ParallelGroup (ParallelGroupId),
    CONSTRAINT CK_wf_WorkflowInstanceStage_Status CHECK (
        Status IN ('Pending','Active','Approved','Rejected','Returned','Skipped','Superseded','Cancelled')
    )
);
GO

-- Concrete work item assigned to a user/role/group for one stage visit.
CREATE TABLE dbo.wf_ApprovalTask (
    ApprovalTaskId        BIGINT IDENTITY(1,1) NOT NULL,
    InstanceStageId       BIGINT           NOT NULL,
    WorkflowInstanceId    UNIQUEIDENTIFIER NOT NULL, -- denormalized for inbox queries
    ApprovalRuleId        INT              NOT NULL,
    AssignedToUserId      UNIQUEIDENTIFIER NULL,
    AssignedToRoleCode    VARCHAR(50)      NULL,
    AssignedToGroupId     INT              NULL,
    Status                VARCHAR(20)      NOT NULL CONSTRAINT DF_wf_ApprovalTask_Status DEFAULT ('Pending'),
    CompletedByUserId     UNIQUEIDENTIFIER NULL,
    Comments              NVARCHAR(1000)   NULL,
    CreatedAt             DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_ApprovalTask_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CompletedAt           DATETIME2(3)     NULL,
    CONSTRAINT PK_wf_ApprovalTask PRIMARY KEY CLUSTERED (ApprovalTaskId),
    CONSTRAINT FK_wf_ApprovalTask_InstanceStage FOREIGN KEY (InstanceStageId)
        REFERENCES dbo.wf_WorkflowInstanceStage (InstanceStageId),
    CONSTRAINT FK_wf_ApprovalTask_Instance FOREIGN KEY (WorkflowInstanceId)
        REFERENCES dbo.wf_WorkflowInstance (WorkflowInstanceId),
    CONSTRAINT FK_wf_ApprovalTask_Rule FOREIGN KEY (ApprovalRuleId) REFERENCES dbo.wf_ApprovalRule (ApprovalRuleId),
    CONSTRAINT FK_wf_ApprovalTask_Group FOREIGN KEY (AssignedToGroupId) REFERENCES dbo.wf_ApprovalGroup (ApprovalGroupId),
    CONSTRAINT CK_wf_ApprovalTask_Status CHECK (Status IN ('Pending','Approved','Rejected','Returned','Cancelled'))
);
GO

-- Append-only audit ledger: every action, actor, and old/new state, ever.
CREATE TABLE dbo.wf_ApprovalAction (
    ApprovalActionId      BIGINT IDENTITY(1,1) NOT NULL,
    WorkflowInstanceId    UNIQUEIDENTIFIER NOT NULL,
    InstanceStageId       BIGINT           NOT NULL,
    ApprovalTaskId        BIGINT           NULL,
    ActionType            VARCHAR(20)      NOT NULL,
    ActorUserId           UNIQUEIDENTIFIER NOT NULL,
    ActionAt              DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_ApprovalAction_ActionAt DEFAULT (SYSUTCDATETIME()),
    OldStatus             VARCHAR(20)      NULL,
    NewStatus             VARCHAR(20)      NULL,
    OldStageId            INT              NULL,
    NewStageId            INT              NULL,
    Comments              NVARCHAR(1000)   NULL,
    ContextSnapshotJson   NVARCHAR(MAX)    NULL,
    CONSTRAINT PK_wf_ApprovalAction PRIMARY KEY CLUSTERED (ApprovalActionId),
    CONSTRAINT FK_wf_ApprovalAction_Instance FOREIGN KEY (WorkflowInstanceId)
        REFERENCES dbo.wf_WorkflowInstance (WorkflowInstanceId),
    CONSTRAINT FK_wf_ApprovalAction_InstanceStage FOREIGN KEY (InstanceStageId)
        REFERENCES dbo.wf_WorkflowInstanceStage (InstanceStageId),
    CONSTRAINT FK_wf_ApprovalAction_Task FOREIGN KEY (ApprovalTaskId) REFERENCES dbo.wf_ApprovalTask (ApprovalTaskId),
    CONSTRAINT FK_wf_ApprovalAction_OldStage FOREIGN KEY (OldStageId) REFERENCES dbo.wf_Stage (StageId),
    CONSTRAINT FK_wf_ApprovalAction_NewStage FOREIGN KEY (NewStageId) REFERENCES dbo.wf_Stage (StageId),
    CONSTRAINT CK_wf_ApprovalAction_ActionType CHECK (
        ActionType IN ('Submit','Approve','Reject','Return','Resume','SystemAdvance','Cancel')
    )
);
GO

-- Thin denormalized cache of external identity, upserted on login.
-- Not a source of truth for identity/roles -- those come from the JWT.
CREATE TABLE dbo.wf_UserRef (
    UserId                UNIQUEIDENTIFIER NOT NULL,
    DisplayName           NVARCHAR(200)    NOT NULL,
    Email                 NVARCHAR(200)    NULL,
    IsActive              BIT              NOT NULL CONSTRAINT DF_wf_UserRef_IsActive DEFAULT (1),
    UpdatedAt             DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_UserRef_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_wf_UserRef PRIMARY KEY CLUSTERED (UserId)
);
GO

CREATE NONCLUSTERED INDEX IX_wf_WorkflowInstance_BusinessEntity ON dbo.wf_WorkflowInstance (BusinessEntityType, BusinessEntityId);
CREATE NONCLUSTERED INDEX IX_wf_WorkflowInstance_Status ON dbo.wf_WorkflowInstance (Status);
CREATE NONCLUSTERED INDEX IX_wf_WorkflowInstance_StartedBy ON dbo.wf_WorkflowInstance (StartedByUserId);
CREATE NONCLUSTERED INDEX IX_wf_WorkflowInstanceStage_Instance ON dbo.wf_WorkflowInstanceStage (WorkflowInstanceId, Status);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalTask_User ON dbo.wf_ApprovalTask (AssignedToUserId, Status);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalTask_Role ON dbo.wf_ApprovalTask (AssignedToRoleCode, Status);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalTask_Group ON dbo.wf_ApprovalTask (AssignedToGroupId, Status);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalTask_Instance ON dbo.wf_ApprovalTask (WorkflowInstanceId);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalTask_InstanceStage ON dbo.wf_ApprovalTask (InstanceStageId);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalAction_Instance ON dbo.wf_ApprovalAction (WorkflowInstanceId, ActionAt);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalAction_InstanceStage ON dbo.wf_ApprovalAction (InstanceStageId);
GO
