-- =============================================================
-- Generic Workflow Engine - Metadata Schema
-- Definition-time tables describing workflow shapes as data.
-- A new business process is added by inserting rows here only.
-- =============================================================

CREATE TABLE dbo.wf_WorkflowDefinition (
    WorkflowDefinitionId INT IDENTITY(1,1) NOT NULL,
    Code                  VARCHAR(50)      NOT NULL,
    Name                  NVARCHAR(200)    NOT NULL,
    Description           NVARCHAR(500)    NULL,
    IsActive              BIT              NOT NULL CONSTRAINT DF_wf_WorkflowDefinition_IsActive DEFAULT (1),
    CreatedAt             DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_WorkflowDefinition_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedByUserId       UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_wf_WorkflowDefinition PRIMARY KEY CLUSTERED (WorkflowDefinitionId),
    CONSTRAINT UQ_wf_WorkflowDefinition_Code UNIQUE (Code)
);
GO

CREATE TABLE dbo.wf_WorkflowVersion (
    WorkflowVersionId     INT IDENTITY(1,1) NOT NULL,
    WorkflowDefinitionId  INT              NOT NULL,
    VersionNumber         INT              NOT NULL,
    Status                VARCHAR(20)      NOT NULL CONSTRAINT DF_wf_WorkflowVersion_Status DEFAULT ('Draft'),
    PublishedAt           DATETIME2(3)     NULL,
    CreatedAt             DATETIME2(3)     NOT NULL CONSTRAINT DF_wf_WorkflowVersion_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CreatedByUserId       UNIQUEIDENTIFIER NULL,
    CONSTRAINT PK_wf_WorkflowVersion PRIMARY KEY CLUSTERED (WorkflowVersionId),
    CONSTRAINT UQ_wf_WorkflowVersion_DefVersion UNIQUE (WorkflowDefinitionId, VersionNumber),
    CONSTRAINT FK_wf_WorkflowVersion_Definition FOREIGN KEY (WorkflowDefinitionId)
        REFERENCES dbo.wf_WorkflowDefinition (WorkflowDefinitionId),
    CONSTRAINT CK_wf_WorkflowVersion_Status CHECK (Status IN ('Draft','Published','Retired'))
);
GO

-- Running instances stay pinned to the WorkflowVersionId they started on,
-- so publishing a new version never changes in-flight instances.
CREATE TABLE dbo.wf_ParallelGroup (
    ParallelGroupId       INT IDENTITY(1,1) NOT NULL,
    WorkflowVersionId     INT           NOT NULL,
    Code                  VARCHAR(50)   NOT NULL,
    Name                  NVARCHAR(200) NOT NULL,
    JoinType              VARCHAR(20)   NOT NULL CONSTRAINT DF_wf_ParallelGroup_JoinType DEFAULT ('All'),
    MinRequiredApprovals  INT           NULL,
    CONSTRAINT PK_wf_ParallelGroup PRIMARY KEY CLUSTERED (ParallelGroupId),
    CONSTRAINT UQ_wf_ParallelGroup_VersionCode UNIQUE (WorkflowVersionId, Code),
    CONSTRAINT FK_wf_ParallelGroup_Version FOREIGN KEY (WorkflowVersionId)
        REFERENCES dbo.wf_WorkflowVersion (WorkflowVersionId),
    CONSTRAINT CK_wf_ParallelGroup_JoinType CHECK (JoinType IN ('All','AnyOne','AnyN')),
    CONSTRAINT CK_wf_ParallelGroup_MinRequired CHECK (JoinType <> 'AnyN' OR MinRequiredApprovals IS NOT NULL)
);
GO

CREATE TABLE dbo.wf_Stage (
    StageId               INT IDENTITY(1,1) NOT NULL,
    WorkflowVersionId     INT           NOT NULL,
    StageKey              VARCHAR(50)   NOT NULL,
    Name                  NVARCHAR(200) NOT NULL,
    StageOrder            INT           NOT NULL,
    StageType             VARCHAR(20)   NOT NULL,
    ParallelGroupId       INT           NULL, -- set when this stage is a branch inside a parallel group
    IsInitial             BIT           NOT NULL CONSTRAINT DF_wf_Stage_IsInitial DEFAULT (0),
    IsFinal               BIT           NOT NULL CONSTRAINT DF_wf_Stage_IsFinal DEFAULT (0),
    CONSTRAINT PK_wf_Stage PRIMARY KEY CLUSTERED (StageId),
    CONSTRAINT UQ_wf_Stage_VersionKey UNIQUE (WorkflowVersionId, StageKey),
    CONSTRAINT FK_wf_Stage_Version FOREIGN KEY (WorkflowVersionId)
        REFERENCES dbo.wf_WorkflowVersion (WorkflowVersionId),
    CONSTRAINT FK_wf_Stage_ParallelGroup FOREIGN KEY (ParallelGroupId)
        REFERENCES dbo.wf_ParallelGroup (ParallelGroupId),
    CONSTRAINT CK_wf_Stage_StageType CHECK (StageType IN ('Start','Approval','ParallelGroup','End'))
);
GO

CREATE TABLE dbo.wf_Transition (
    TransitionId          INT IDENTITY(1,1) NOT NULL,
    WorkflowVersionId     INT            NOT NULL,
    FromStageId           INT            NOT NULL,
    ToStageId             INT            NOT NULL,
    ConditionExpression   NVARCHAR(500)  NULL, -- e.g. "Amount > 50000"; NULL when IsDefault. Evaluated in .NET via NCalc, not T-SQL.
    Priority              INT            NOT NULL CONSTRAINT DF_wf_Transition_Priority DEFAULT (100),
    IsDefault             BIT            NOT NULL CONSTRAINT DF_wf_Transition_IsDefault DEFAULT (0),
    CONSTRAINT PK_wf_Transition PRIMARY KEY CLUSTERED (TransitionId),
    CONSTRAINT FK_wf_Transition_Version FOREIGN KEY (WorkflowVersionId)
        REFERENCES dbo.wf_WorkflowVersion (WorkflowVersionId),
    CONSTRAINT FK_wf_Transition_FromStage FOREIGN KEY (FromStageId) REFERENCES dbo.wf_Stage (StageId),
    CONSTRAINT FK_wf_Transition_ToStage FOREIGN KEY (ToStageId) REFERENCES dbo.wf_Stage (StageId)
);
GO

CREATE TABLE dbo.wf_ApprovalGroup (
    ApprovalGroupId       INT IDENTITY(1,1) NOT NULL,
    Code                  VARCHAR(50)   NOT NULL,
    Name                  NVARCHAR(200) NOT NULL,
    IsActive              BIT           NOT NULL CONSTRAINT DF_wf_ApprovalGroup_IsActive DEFAULT (1),
    CONSTRAINT PK_wf_ApprovalGroup PRIMARY KEY CLUSTERED (ApprovalGroupId),
    CONSTRAINT UQ_wf_ApprovalGroup_Code UNIQUE (Code)
);
GO

CREATE TABLE dbo.wf_ApprovalGroupMember (
    ApprovalGroupMemberId INT IDENTITY(1,1) NOT NULL,
    ApprovalGroupId       INT              NOT NULL,
    MemberType            VARCHAR(10)      NOT NULL, -- User | Role
    UserId                UNIQUEIDENTIFIER NULL,
    RoleCode              VARCHAR(50)      NULL,
    IsActive              BIT              NOT NULL CONSTRAINT DF_wf_ApprovalGroupMember_IsActive DEFAULT (1),
    CONSTRAINT PK_wf_ApprovalGroupMember PRIMARY KEY CLUSTERED (ApprovalGroupMemberId),
    CONSTRAINT FK_wf_ApprovalGroupMember_Group FOREIGN KEY (ApprovalGroupId)
        REFERENCES dbo.wf_ApprovalGroup (ApprovalGroupId),
    CONSTRAINT CK_wf_ApprovalGroupMember_MemberType CHECK (MemberType IN ('User','Role')),
    CONSTRAINT CK_wf_ApprovalGroupMember_Ref CHECK (
        (MemberType = 'User' AND UserId IS NOT NULL AND RoleCode IS NULL) OR
        (MemberType = 'Role' AND RoleCode IS NOT NULL AND UserId IS NULL)
    )
);
GO

CREATE TABLE dbo.wf_ApprovalRule (
    ApprovalRuleId        INT IDENTITY(1,1) NOT NULL,
    StageId               INT              NOT NULL,
    ApproverType          VARCHAR(10)      NOT NULL, -- User | Role | Group
    SpecificUserId        UNIQUEIDENTIFIER NULL,
    ApproverRoleCode      VARCHAR(50)      NULL,
    ApprovalGroupId       INT              NULL,
    RequiredCount         INT              NOT NULL CONSTRAINT DF_wf_ApprovalRule_RequiredCount DEFAULT (1),
    CONSTRAINT PK_wf_ApprovalRule PRIMARY KEY CLUSTERED (ApprovalRuleId),
    CONSTRAINT FK_wf_ApprovalRule_Stage FOREIGN KEY (StageId) REFERENCES dbo.wf_Stage (StageId),
    CONSTRAINT FK_wf_ApprovalRule_Group FOREIGN KEY (ApprovalGroupId) REFERENCES dbo.wf_ApprovalGroup (ApprovalGroupId),
    CONSTRAINT CK_wf_ApprovalRule_ApproverType CHECK (ApproverType IN ('User','Role','Group')),
    CONSTRAINT CK_wf_ApprovalRule_Ref CHECK (
        (ApproverType = 'User'  AND SpecificUserId IS NOT NULL AND ApproverRoleCode IS NULL AND ApprovalGroupId IS NULL) OR
        (ApproverType = 'Role'  AND ApproverRoleCode IS NOT NULL AND SpecificUserId IS NULL AND ApprovalGroupId IS NULL) OR
        (ApproverType = 'Group' AND ApprovalGroupId IS NOT NULL AND SpecificUserId IS NULL AND ApproverRoleCode IS NULL)
    )
);
GO

-- RequiredCount=1 against a group means "any one of"; RequiredCount = member
-- count (resolved at task-creation time) means "all of".
CREATE TABLE dbo.wf_ReturnRule (
    ReturnRuleId           INT IDENTITY(1,1) NOT NULL,
    FromStageId            INT NOT NULL,
    ToStageId              INT NOT NULL,
    ResetApprovalsOnReturn BIT NOT NULL CONSTRAINT DF_wf_ReturnRule_Reset DEFAULT (1),
    RequireComment         BIT NOT NULL CONSTRAINT DF_wf_ReturnRule_RequireComment DEFAULT (1),
    CONSTRAINT PK_wf_ReturnRule PRIMARY KEY CLUSTERED (ReturnRuleId),
    CONSTRAINT FK_wf_ReturnRule_FromStage FOREIGN KEY (FromStageId) REFERENCES dbo.wf_Stage (StageId),
    CONSTRAINT FK_wf_ReturnRule_ToStage FOREIGN KEY (ToStageId) REFERENCES dbo.wf_Stage (StageId)
);
GO

CREATE NONCLUSTERED INDEX IX_wf_WorkflowVersion_Definition ON dbo.wf_WorkflowVersion (WorkflowDefinitionId, Status);
CREATE NONCLUSTERED INDEX IX_wf_ParallelGroup_Version ON dbo.wf_ParallelGroup (WorkflowVersionId);
CREATE NONCLUSTERED INDEX IX_wf_Stage_Version ON dbo.wf_Stage (WorkflowVersionId, StageOrder);
CREATE NONCLUSTERED INDEX IX_wf_Stage_ParallelGroup ON dbo.wf_Stage (ParallelGroupId);
CREATE NONCLUSTERED INDEX IX_wf_Transition_FromStage ON dbo.wf_Transition (FromStageId, Priority);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalGroupMember_Group ON dbo.wf_ApprovalGroupMember (ApprovalGroupId, IsActive);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalRule_Stage ON dbo.wf_ApprovalRule (StageId);
CREATE NONCLUSTERED INDEX IX_wf_ApprovalRule_Group ON dbo.wf_ApprovalRule (ApprovalGroupId);
CREATE NONCLUSTERED INDEX IX_wf_ReturnRule_FromStage ON dbo.wf_ReturnRule (FromStageId);
GO
