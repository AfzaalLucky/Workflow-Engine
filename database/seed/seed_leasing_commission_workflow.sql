-- =============================================================
-- Seed: Leasing Commission workflow, defined ENTIRELY as metadata
-- rows (see LeasingFlow.md for the source business rules). Second
-- proof of genericness alongside Purchase Request: a completely
-- different approval chain, with a harder return/resume case, and
-- again zero wf_* schema changes.
--
-- Shape being modeled (legacy status codes from LeasingFlow.md in parens):
--   Initiated (1)
--     -> LeasingApproval (20)
--     -> Finance+CC parallel gate (23): Finance (4) AND CC (19), both required
--     -> AuditApproval (5)
--     -> FinanceClearance (6)
--     -> Cleared (7, terminal)
--
--   Return path: Audit can return the record to a dedicated
--   "ReturnFromAudit" stage (14) rather than reusing LeasingApproval's
--   stage. That stage's own outgoing transition goes DIRECTLY back to
--   AuditApproval, skipping the Finance/CC gate entirely -- this is
--   what makes "resume to the exact stage it was returned from" work:
--   the resume path is a different edge in the graph, not a re-walk of
--   the forward chain. ResetApprovalsOnReturn=0 here because the prior
--   Finance/CC/Leasing approvals are still valid; only Audit needs to
--   look at it again.
--
-- Idempotent: safe to re-run.
-- =============================================================
SET NOCOUNT ON;

DECLARE @DefId INT, @VerId INT, @ParallelGroupId INT;
DECLARE @InitiatedStageId INT, @LeasingApprovalStageId INT, @GateStageId INT,
        @FinanceStageId INT, @CCStageId INT, @AuditStageId INT,
        @FinanceClearanceStageId INT, @ClearedStageId INT, @ReturnFromAuditStageId INT;

-- 1. Workflow definition + published version
IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowDefinition WHERE Code = 'LEASING_COMMISSION')
    INSERT INTO dbo.wf_WorkflowDefinition (Code, Name, Description)
    VALUES ('LEASING_COMMISSION', 'Leasing Commission Approval',
            'Leasing commission approval chain: Leasing -> parallel Finance+CC -> Audit -> Finance Clearance -> Cleared, with return-to-exact-origin from Audit.');
SELECT @DefId = WorkflowDefinitionId FROM dbo.wf_WorkflowDefinition WHERE Code = 'LEASING_COMMISSION';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowVersion WHERE WorkflowDefinitionId = @DefId AND VersionNumber = 1)
    INSERT INTO dbo.wf_WorkflowVersion (WorkflowDefinitionId, VersionNumber, Status, PublishedAt)
    VALUES (@DefId, 1, 'Published', SYSUTCDATETIME());
SELECT @VerId = WorkflowVersionId FROM dbo.wf_WorkflowVersion WHERE WorkflowDefinitionId = @DefId AND VersionNumber = 1;

-- 2. Parallel group: Finance + CC, both required
IF NOT EXISTS (SELECT 1 FROM dbo.wf_ParallelGroup WHERE WorkflowVersionId = @VerId AND Code = 'FINANCE_CC_GATE')
    INSERT INTO dbo.wf_ParallelGroup (WorkflowVersionId, Code, Name, JoinType)
    VALUES (@VerId, 'FINANCE_CC_GATE', 'Finance & Credit Control Approval', 'All');
SELECT @ParallelGroupId = ParallelGroupId FROM dbo.wf_ParallelGroup WHERE WorkflowVersionId = @VerId AND Code = 'FINANCE_CC_GATE';

-- 3. Stages
IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'INITIATED')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, IsInitial)
    VALUES (@VerId, 'INITIATED', 'Initiated (Status 1)', 10, 'Start', 1);
SELECT @InitiatedStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'INITIATED';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'LEASING_APPROVAL')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType)
    VALUES (@VerId, 'LEASING_APPROVAL', 'Under Leasing Approval (Status 20)', 20, 'Approval');
SELECT @LeasingApprovalStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'LEASING_APPROVAL';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINANCE_CC_GATE')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, ParallelGroupId)
    VALUES (@VerId, 'FINANCE_CC_GATE', 'Under Approval from Finance and CC (Status 23)', 30, 'ParallelGroup', @ParallelGroupId);
SELECT @GateStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINANCE_CC_GATE';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINANCE_APPROVAL')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, ParallelGroupId)
    VALUES (@VerId, 'FINANCE_APPROVAL', 'Finance Approval (Status 4)', 30, 'Approval', @ParallelGroupId);
SELECT @FinanceStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINANCE_APPROVAL';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'CC_APPROVAL')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, ParallelGroupId)
    VALUES (@VerId, 'CC_APPROVAL', 'Credit Control Approval (Status 19)', 30, 'Approval', @ParallelGroupId);
SELECT @CCStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'CC_APPROVAL';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'AUDIT_APPROVAL')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType)
    VALUES (@VerId, 'AUDIT_APPROVAL', 'Under Audit Approval (Status 5)', 40, 'Approval');
SELECT @AuditStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'AUDIT_APPROVAL';

-- Placed near Audit in StageOrder since it is a detour, not a step back
-- through the whole forward chain -- see the header comment.
IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'RETURN_FROM_AUDIT')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType)
    VALUES (@VerId, 'RETURN_FROM_AUDIT', 'Return from Audit (Status 14)', 35, 'Approval');
SELECT @ReturnFromAuditStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'RETURN_FROM_AUDIT';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINANCE_CLEARANCE')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType)
    VALUES (@VerId, 'FINANCE_CLEARANCE', 'Finance Clearance (Status 6)', 50, 'Approval');
SELECT @FinanceClearanceStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINANCE_CLEARANCE';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'CLEARED')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, IsFinal)
    VALUES (@VerId, 'CLEARED', 'Cleared (Status 7)', 60, 'End', 1);
SELECT @ClearedStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'CLEARED';

-- 4. Transitions
IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @InitiatedStageId AND ToStageId = @LeasingApprovalStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @InitiatedStageId, @LeasingApprovalStageId, 100, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @LeasingApprovalStageId AND ToStageId = @GateStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @LeasingApprovalStageId, @GateStageId, 100, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @GateStageId AND ToStageId = @AuditStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @GateStageId, @AuditStageId, 100, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @AuditStageId AND ToStageId = @FinanceClearanceStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @AuditStageId, @FinanceClearanceStageId, 100, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @FinanceClearanceStageId AND ToStageId = @ClearedStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @FinanceClearanceStageId, @ClearedStageId, 100, 1);

-- The resume path: re-approving a returned-from-audit item goes straight
-- back to Audit, never re-touching the Finance/CC gate.
IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @ReturnFromAuditStageId AND ToStageId = @AuditStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @ReturnFromAuditStageId, @AuditStageId, 100, 1);

-- 5. Approval rules
IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @LeasingApprovalStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@LeasingApprovalStageId, 'Role', 'LeasingApprover', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @FinanceStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@FinanceStageId, 'Role', 'LeasingFinanceApprover', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @CCStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@CCStageId, 'Role', 'LeasingCCApprover', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @AuditStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@AuditStageId, 'Role', 'LeasingAuditor', 1);

-- Same approver role as LEASING_APPROVAL: this stage functionally "lands
-- back on Leasing" per LeasingFlow.md, just via a different graph edge.
IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @ReturnFromAuditStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@ReturnFromAuditStageId, 'Role', 'LeasingApprover', 1);

-- Finance Clearance is its own distinct role from the Finance Approval
-- branch (Status 4) -- a different function/team signs off at clearance.
IF EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @FinanceClearanceStageId)
    UPDATE dbo.wf_ApprovalRule SET ApproverType = 'Role', ApproverRoleCode = 'LeasingFinanceClearanceApprover', ApprovalGroupId = NULL, SpecificUserId = NULL
    WHERE StageId = @FinanceClearanceStageId;
ELSE
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@FinanceClearanceStageId, 'Role', 'LeasingFinanceClearanceApprover', 1);

-- 6. Return rule: Audit can bounce the record back to the dedicated
-- return stage. ResetApprovalsOnReturn=0 because the Leasing/Finance/CC
-- approvals already on record remain valid -- the resume transition
-- above skips straight back to Audit without re-touching them.
IF NOT EXISTS (SELECT 1 FROM dbo.wf_ReturnRule WHERE FromStageId = @AuditStageId AND ToStageId = @ReturnFromAuditStageId)
    INSERT INTO dbo.wf_ReturnRule (FromStageId, ToStageId, ResetApprovalsOnReturn, RequireComment)
    VALUES (@AuditStageId, @ReturnFromAuditStageId, 0, 1);

SELECT
    @DefId AS WorkflowDefinitionId, @VerId AS WorkflowVersionId, @ParallelGroupId AS ParallelGroupId,
    @InitiatedStageId AS InitiatedStageId, @LeasingApprovalStageId AS LeasingApprovalStageId,
    @GateStageId AS GateStageId, @FinanceStageId AS FinanceStageId, @CCStageId AS CCStageId,
    @AuditStageId AS AuditStageId, @ReturnFromAuditStageId AS ReturnFromAuditStageId,
    @FinanceClearanceStageId AS FinanceClearanceStageId, @ClearedStageId AS ClearedStageId;
