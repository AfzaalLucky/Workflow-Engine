-- =============================================================
-- End-to-end verification of the engine against the seeded
-- Purchase Request workflow. Run after 00_deploy_all.sql.
--
-- Simulates what the .NET layer will do: call an engine proc, read
-- back @NeedsRouting/@RoutingFromStageId, resolve the next stage via
-- wf_GetCandidateTransitions (condition evaluation stands in for NCalc
-- here since there's no .NET host in this script), then call
-- wf_AdvanceToStage. Prints state at each step for manual inspection.
--
-- Part 1: happy path, Amount=75000 (routes through Finance + parallel
--         Legal/Procurement + Final, since 75000 > 1000).
-- Part 2: return-then-resume path.
-- =============================================================
SET NOCOUNT ON;

DECLARE @Requester UNIQUEIDENTIFIER = 'AAAAAAAA-0000-0000-0000-000000000001';
DECLARE @Manager UNIQUEIDENTIFIER = 'AAAAAAAA-0000-0000-0000-000000000002';
DECLARE @FinanceUser UNIQUEIDENTIFIER = 'AAAAAAAA-0000-0000-0000-000000000003';
DECLARE @LegalUser UNIQUEIDENTIFIER = 'AAAAAAAA-0000-0000-0000-000000000004';
DECLARE @ProcurementUser UNIQUEIDENTIFIER = 'AAAAAAAA-0000-0000-0000-000000000005';
DECLARE @Director UNIQUEIDENTIFIER = 'AAAAAAAA-0000-0000-0000-000000000006';

DECLARE @ManagerRoles dbo.wf_RoleCodeList; INSERT INTO @ManagerRoles VALUES ('Manager');
DECLARE @FinanceRoles dbo.wf_RoleCodeList; INSERT INTO @FinanceRoles VALUES ('FinanceApprover');
DECLARE @LegalRoles dbo.wf_RoleCodeList; INSERT INTO @LegalRoles VALUES ('Legal');
DECLARE @ProcurementRoles dbo.wf_RoleCodeList; INSERT INTO @ProcurementRoles VALUES ('Procurement');
DECLARE @DirectorRoles dbo.wf_RoleCodeList; INSERT INTO @DirectorRoles VALUES ('Director');

PRINT '=== PART 1: Happy path (Amount = 75000) ===';

DECLARE @InstanceId UNIQUEIDENTIFIER, @StageId INT;
EXEC dbo.wf_StartWorkflowInstance
    @WorkflowDefinitionCode = 'PURCHASE_REQUEST',
    @BusinessEntityType = 'PurchaseRequest',
    @BusinessEntityId = 'TEST-001',
    @ContextDataJson = N'{"Amount":75000}',
    @StartedByUserId = @Requester,
    @WorkflowInstanceId = @InstanceId OUTPUT,
    @InitialStageId = @StageId OUTPUT;
PRINT 'Started instance ' + CAST(@InstanceId AS NVARCHAR(50)) + ' at stage ' + CAST(@StageId AS NVARCHAR(10));

-- Resolve Start -> next (single default transition -> Manager Approval)
DECLARE @ToStageId INT;
EXEC dbo.wf_GetCandidateTransitions @FromStageId = @StageId; -- inspect manually; only one default row expected

SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @StageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @Requester;
PRINT 'Advanced Start -> Manager Approval (stage ' + CAST(@ToStageId AS NVARCHAR(10)) + ')';

-- Manager approves
DECLARE @TaskId BIGINT, @NeedsRouting BIT, @RoutingFromStageId INT, @WiId UNIQUEIDENTIFIER;
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @Manager, @ActorRoleCodes = @ManagerRoles,
    @Action = 'Approve', @Comments = 'Looks good',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
PRINT 'Manager approved. NeedsRouting=' + CAST(@NeedsRouting AS CHAR(1));

-- Routing: Amount(75000) > 1000, so the conditional End-transition does NOT
-- match; take the default (Finance Approval).
SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @RoutingFromStageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @Manager;
PRINT 'Advanced Manager -> Finance Approval (stage ' + CAST(@ToStageId AS NVARCHAR(10)) + ')';

-- Finance (any-one-of) approves
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @FinanceUser, @ActorRoleCodes = @FinanceRoles,
    @Action = 'Approve', @Comments = 'Budget ok',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
PRINT 'Finance approved. NeedsRouting=' + CAST(@NeedsRouting AS CHAR(1));

SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @RoutingFromStageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @FinanceUser;
PRINT 'Advanced Finance -> Legal+Procurement parallel review (container stage ' + CAST(@ToStageId AS NVARCHAR(10)) + ')';

SELECT ApprovalTaskId, AssignedToRoleCode FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';

-- Legal approves first: join type All, so the group should NOT complete yet
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending' AND AssignedToRoleCode = 'Legal';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @LegalUser, @ActorRoleCodes = @LegalRoles,
    @Action = 'Approve', @Comments = 'Contract terms fine',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
PRINT 'Legal approved. NeedsRouting=' + CAST(@NeedsRouting AS CHAR(1)) + ' (expected 0 - still waiting on Procurement)';

-- Procurement approves second: join type All is now satisfied
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending' AND AssignedToRoleCode = 'Procurement';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @ProcurementUser, @ActorRoleCodes = @ProcurementRoles,
    @Action = 'Approve', @Comments = 'Vendor approved',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
PRINT 'Procurement approved. NeedsRouting=' + CAST(@NeedsRouting AS CHAR(1)) + ' (expected 1 - parallel group now complete)';

SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @RoutingFromStageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @ProcurementUser;
PRINT 'Advanced parallel review -> Final Approval (stage ' + CAST(@ToStageId AS NVARCHAR(10)) + ')';

-- Director gives final approval
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @Director, @ActorRoleCodes = @DirectorRoles,
    @Action = 'Approve', @Comments = 'Approved',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;

SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @RoutingFromStageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @Director;
PRINT 'Advanced Final Approval -> End (stage ' + CAST(@ToStageId AS NVARCHAR(10)) + ')';

PRINT '--- Instance status (expect Status = Approved) ---';
EXEC dbo.wf_GetWorkflowInstanceStatus @WorkflowInstanceId = @InstanceId;

PRINT '--- Full audit trail ---';
EXEC dbo.wf_GetWorkflowInstanceHistory @WorkflowInstanceId = @InstanceId;


PRINT '=== PART 2: Return then Resume ===';

DECLARE @InstanceId2 UNIQUEIDENTIFIER, @StageId2 INT;
EXEC dbo.wf_StartWorkflowInstance
    @WorkflowDefinitionCode = 'PURCHASE_REQUEST',
    @BusinessEntityType = 'PurchaseRequest',
    @BusinessEntityId = 'TEST-002',
    @ContextDataJson = N'{"Amount":5000}',
    @StartedByUserId = @Requester,
    @WorkflowInstanceId = @InstanceId2 OUTPUT,
    @InitialStageId = @StageId2 OUTPUT;

DECLARE @ToStageId2 INT;
SELECT TOP 1 @ToStageId2 = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @StageId2 AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId2, @ToStageId = @ToStageId2, @ActorUserId = @Requester;
PRINT 'Instance 2 advanced Start -> Manager Approval';

DECLARE @TaskId2 BIGINT;
SELECT TOP 1 @TaskId2 = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId2 AND Status = 'Pending';

DECLARE @WiId2 UNIQUEIDENTIFIER, @NeedsRouting2 BIT, @RoutingFromStageId2 INT;
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId2, @ActorUserId = @Manager, @ActorRoleCodes = @ManagerRoles,
    @Action = 'Return', @Comments = 'Missing cost center, please add it',
    @WorkflowInstanceId = @WiId2 OUTPUT, @NeedsRouting = @NeedsRouting2 OUTPUT, @RoutingFromStageId = @RoutingFromStageId2 OUTPUT;

PRINT '--- Status after Return (expect Status = Returned, CurrentStage = Submitted) ---';
EXEC dbo.wf_GetWorkflowInstanceStatus @WorkflowInstanceId = @InstanceId2;

DECLARE @CurrentStageId2 INT, @ResumeNeedsRouting BIT;
EXEC dbo.wf_ResumeWorkflowInstance
    @WorkflowInstanceId = @InstanceId2,
    @ActorUserId = @Requester,
    @UpdatedContextDataJson = N'{"Amount":5000,"CostCenter":"CC-100"}',
    @CurrentStageId = @CurrentStageId2 OUTPUT,
    @NeedsRouting = @ResumeNeedsRouting OUTPUT;
PRINT 'Resumed at stage ' + CAST(@CurrentStageId2 AS NVARCHAR(10)) + '. NeedsRouting=' + CAST(@ResumeNeedsRouting AS CHAR(1)) + ' (expected 1 - Start has no approver)';

DECLARE @ResumeToStageId INT;
SELECT TOP 1 @ResumeToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @CurrentStageId2 AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId2, @ToStageId = @ResumeToStageId, @ActorUserId = @Requester;
PRINT 'Re-advanced Start -> Manager Approval (2nd attempt) after resume';

SELECT ApprovalTaskId, AssignedToRoleCode, CreatedAt FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId2 ORDER BY CreatedAt;

PRINT '--- Full audit trail for instance 2 (expect Submit, SystemAdvance, Approve-none, Return, Resume, SystemAdvance) ---';
EXEC dbo.wf_GetWorkflowInstanceHistory @WorkflowInstanceId = @InstanceId2;
