-- =============================================================
-- Seed: Purchase Request workflow, defined ENTIRELY as metadata rows.
-- No wf_* schema changes are needed to add this (or any other)
-- business process -- this script is the proof.
--
-- Shape being modeled:
--   Start
--     -> ManagerApproval (single approver, role Manager)
--        -- dynamic routing: Amount <= 1000 skips straight to End
--     -> FinanceApproval (approval group "Finance Team", any-one-of)
--     -> LegalProcurementReview (parallel: Legal AND Procurement both required)
--     -> FinalApproval (single approver, role Director)
--     -> End
--   Return path: Manager/Finance/Final approvers can return to Start;
--   requester edits and calls Resume to re-enter the workflow.
--
-- Idempotent: safe to re-run.
-- =============================================================
SET NOCOUNT ON;

DECLARE @DefId INT, @VerId INT, @FinanceGroupId INT, @ParallelGroupId INT;
DECLARE @StartStageId INT, @ManagerStageId INT, @FinanceStageId INT,
        @ParallelContainerStageId INT, @LegalStageId INT, @ProcurementStageId INT,
        @FinalStageId INT, @EndStageId INT;

-- 1. Workflow definition + published version
IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowDefinition WHERE Code = 'PURCHASE_REQUEST')
    INSERT INTO dbo.wf_WorkflowDefinition (Code, Name, Description)
    VALUES ('PURCHASE_REQUEST', 'Purchase Request Approval',
            'Sample end-to-end workflow proving the generic engine: sequential + group + parallel approvals, dynamic routing, return/resume.');
SELECT @DefId = WorkflowDefinitionId FROM dbo.wf_WorkflowDefinition WHERE Code = 'PURCHASE_REQUEST';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowVersion WHERE WorkflowDefinitionId = @DefId AND VersionNumber = 1)
    INSERT INTO dbo.wf_WorkflowVersion (WorkflowDefinitionId, VersionNumber, Status, PublishedAt)
    VALUES (@DefId, 1, 'Published', SYSUTCDATETIME());
SELECT @VerId = WorkflowVersionId FROM dbo.wf_WorkflowVersion WHERE WorkflowDefinitionId = @DefId AND VersionNumber = 1;

-- 2. Approval group: Finance Team (role-based membership; any user whose JWT
--    carries the FinanceApprover role is an eligible member -- no need to
--    pre-enumerate specific user GUIDs here)
IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalGroup WHERE Code = 'FINANCE_TEAM')
    INSERT INTO dbo.wf_ApprovalGroup (Code, Name) VALUES ('FINANCE_TEAM', 'Finance Team');
SELECT @FinanceGroupId = ApprovalGroupId FROM dbo.wf_ApprovalGroup WHERE Code = 'FINANCE_TEAM';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalGroupMember WHERE ApprovalGroupId = @FinanceGroupId AND MemberType = 'Role' AND RoleCode = 'FinanceApprover')
    INSERT INTO dbo.wf_ApprovalGroupMember (ApprovalGroupId, MemberType, RoleCode)
    VALUES (@FinanceGroupId, 'Role', 'FinanceApprover');

-- 3. Parallel group: Legal + Procurement, both required
IF NOT EXISTS (SELECT 1 FROM dbo.wf_ParallelGroup WHERE WorkflowVersionId = @VerId AND Code = 'LEGAL_PROCUREMENT')
    INSERT INTO dbo.wf_ParallelGroup (WorkflowVersionId, Code, Name, JoinType)
    VALUES (@VerId, 'LEGAL_PROCUREMENT', 'Legal & Procurement Review', 'All');
SELECT @ParallelGroupId = ParallelGroupId FROM dbo.wf_ParallelGroup WHERE WorkflowVersionId = @VerId AND Code = 'LEGAL_PROCUREMENT';

-- 4. Stages
IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'START')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, IsInitial)
    VALUES (@VerId, 'START', 'Submitted', 10, 'Start', 1);
SELECT @StartStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'START';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'MANAGER_APPROVAL')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType)
    VALUES (@VerId, 'MANAGER_APPROVAL', 'Manager Approval', 20, 'Approval');
SELECT @ManagerStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'MANAGER_APPROVAL';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINANCE_APPROVAL')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType)
    VALUES (@VerId, 'FINANCE_APPROVAL', 'Finance Team Approval', 30, 'Approval');
SELECT @FinanceStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINANCE_APPROVAL';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'LEGAL_PROCUREMENT_REVIEW')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, ParallelGroupId)
    VALUES (@VerId, 'LEGAL_PROCUREMENT_REVIEW', 'Legal & Procurement Review', 40, 'ParallelGroup', @ParallelGroupId);
SELECT @ParallelContainerStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'LEGAL_PROCUREMENT_REVIEW';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'LEGAL_REVIEW')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, ParallelGroupId)
    VALUES (@VerId, 'LEGAL_REVIEW', 'Legal Review', 40, 'Approval', @ParallelGroupId);
SELECT @LegalStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'LEGAL_REVIEW';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'PROCUREMENT_REVIEW')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, ParallelGroupId)
    VALUES (@VerId, 'PROCUREMENT_REVIEW', 'Procurement Review', 40, 'Approval', @ParallelGroupId);
SELECT @ProcurementStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'PROCUREMENT_REVIEW';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINAL_APPROVAL')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType)
    VALUES (@VerId, 'FINAL_APPROVAL', 'Final Approval', 50, 'Approval');
SELECT @FinalStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINAL_APPROVAL';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'END')
    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, IsFinal)
    VALUES (@VerId, 'END', 'Completed', 60, 'End', 1);
SELECT @EndStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'END';

-- 5. Transitions
IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @StartStageId AND ToStageId = @ManagerStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @StartStageId, @ManagerStageId, 100, 1);

-- Dynamic routing demo: small purchases skip straight to completion.
IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @ManagerStageId AND ToStageId = @EndStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, ConditionExpression, Priority, IsDefault)
    VALUES (@VerId, @ManagerStageId, @EndStageId, 'Amount <= 1000', 10, 0);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @ManagerStageId AND ToStageId = @FinanceStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @ManagerStageId, @FinanceStageId, 100, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @FinanceStageId AND ToStageId = @ParallelContainerStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @FinanceStageId, @ParallelContainerStageId, 100, 1);

-- Taken once wf_TryCompleteParallelGroup marks the container's instance stage Approved.
IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @ParallelContainerStageId AND ToStageId = @FinalStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @ParallelContainerStageId, @FinalStageId, 100, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE FromStageId = @FinalStageId AND ToStageId = @EndStageId)
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, Priority, IsDefault)
    VALUES (@VerId, @FinalStageId, @EndStageId, 100, 1);

-- 6. Approval rules
IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @ManagerStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@ManagerStageId, 'Role', 'Manager', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @FinanceStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApprovalGroupId, RequiredCount)
    VALUES (@FinanceStageId, 'Group', @FinanceGroupId, 1); -- any-one-of

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @LegalStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@LegalStageId, 'Role', 'Legal', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @ProcurementStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@ProcurementStageId, 'Role', 'Procurement', 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE StageId = @FinalStageId)
    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, RequiredCount)
    VALUES (@FinalStageId, 'Role', 'Director', 1);

-- 7. Return rules: any approval stage can send the request back to the
--    requester; requester edits and calls Resume to re-enter at Start.
IF NOT EXISTS (SELECT 1 FROM dbo.wf_ReturnRule WHERE FromStageId = @ManagerStageId AND ToStageId = @StartStageId)
    INSERT INTO dbo.wf_ReturnRule (FromStageId, ToStageId, ResetApprovalsOnReturn, RequireComment)
    VALUES (@ManagerStageId, @StartStageId, 1, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ReturnRule WHERE FromStageId = @FinanceStageId AND ToStageId = @StartStageId)
    INSERT INTO dbo.wf_ReturnRule (FromStageId, ToStageId, ResetApprovalsOnReturn, RequireComment)
    VALUES (@FinanceStageId, @StartStageId, 1, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.wf_ReturnRule WHERE FromStageId = @FinalStageId AND ToStageId = @StartStageId)
    INSERT INTO dbo.wf_ReturnRule (FromStageId, ToStageId, ResetApprovalsOnReturn, RequireComment)
    VALUES (@FinalStageId, @StartStageId, 1, 1);

SELECT
    @DefId AS WorkflowDefinitionId, @VerId AS WorkflowVersionId,
    @FinanceGroupId AS FinanceGroupId, @ParallelGroupId AS ParallelGroupId,
    @StartStageId AS StartStageId, @ManagerStageId AS ManagerStageId,
    @FinanceStageId AS FinanceStageId, @ParallelContainerStageId AS ParallelContainerStageId,
    @LegalStageId AS LegalStageId, @ProcurementStageId AS ProcurementStageId,
    @FinalStageId AS FinalStageId, @EndStageId AS EndStageId;
