-- =============================================================
-- End-to-end verification of the Leasing Commission workflow,
-- focused on the hard case: Audit returns the record, and
-- re-approving it must resume directly back to Audit -- skipping
-- the Finance/CC gate -- rather than re-walking the forward chain.
-- Run after seed_leasing_commission_workflow.sql.
-- =============================================================
SET NOCOUNT ON;

DECLARE @Requester UNIQUEIDENTIFIER = 'BBBBBBBB-0000-0000-0000-000000000001';
DECLARE @LeasingOfficer UNIQUEIDENTIFIER = 'BBBBBBBB-0000-0000-0000-000000000002';
DECLARE @FinanceUser UNIQUEIDENTIFIER = 'BBBBBBBB-0000-0000-0000-000000000003';
DECLARE @CCUser UNIQUEIDENTIFIER = 'BBBBBBBB-0000-0000-0000-000000000004';
DECLARE @Auditor UNIQUEIDENTIFIER = 'BBBBBBBB-0000-0000-0000-000000000005';

DECLARE @LeasingRoles dbo.wf_RoleCodeList; INSERT INTO @LeasingRoles VALUES ('LeasingApprover');
DECLARE @FinanceRoles dbo.wf_RoleCodeList; INSERT INTO @FinanceRoles VALUES ('LeasingFinanceApprover');
DECLARE @CCRoles dbo.wf_RoleCodeList; INSERT INTO @CCRoles VALUES ('LeasingCCApprover');
DECLARE @AuditorRoles dbo.wf_RoleCodeList; INSERT INTO @AuditorRoles VALUES ('LeasingAuditor');

PRINT '=== Leasing Commission: Audit return-to-exact-origin ===';

DECLARE @InstanceId UNIQUEIDENTIFIER, @StageId INT, @ToStageId INT;
EXEC dbo.wf_StartWorkflowInstance
    @WorkflowDefinitionCode = 'LEASING_COMMISSION',
    @BusinessEntityType = 'LeasingCommission',
    @BusinessEntityId = 'LC-TEST-001',
    @ContextDataJson = N'{"CommissionAmount":15000}',
    @StartedByUserId = @Requester,
    @WorkflowInstanceId = @InstanceId OUTPUT,
    @InitialStageId = @StageId OUTPUT;

SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @StageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @Requester;
PRINT 'Initiated -> Leasing Approval';

DECLARE @TaskId BIGINT, @NeedsRouting BIT, @RoutingFromStageId INT, @WiId UNIQUEIDENTIFIER;

-- Leasing approves -> Finance+CC gate
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @LeasingOfficer, @ActorRoleCodes = @LeasingRoles,
    @Action = 'Approve', @Comments = 'Leasing ok',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @RoutingFromStageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @LeasingOfficer;
PRINT 'Leasing Approval -> Finance/CC gate (fanned out)';

SELECT ApprovalTaskId, AssignedToRoleCode FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';

-- Finance approves (gate not yet complete)
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending' AND AssignedToRoleCode = 'LeasingFinanceApprover';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @FinanceUser, @ActorRoleCodes = @FinanceRoles,
    @Action = 'Approve', @Comments = 'Finance ok',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
PRINT 'Finance approved. NeedsRouting=' + CAST(@NeedsRouting AS CHAR(1)) + ' (expected 0)';

-- CC approves (gate now complete) -> Audit
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending' AND AssignedToRoleCode = 'LeasingCCApprover';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @CCUser, @ActorRoleCodes = @CCRoles,
    @Action = 'Approve', @Comments = 'CC ok',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
PRINT 'CC approved. NeedsRouting=' + CAST(@NeedsRouting AS CHAR(1)) + ' (expected 1 - gate complete)';

SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @RoutingFromStageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @CCUser;
PRINT 'Finance/CC gate -> Audit Approval';

-- Audit RETURNS the record instead of approving
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @Auditor, @ActorRoleCodes = @AuditorRoles,
    @Action = 'Return', @Comments = 'Missing supporting documents',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;

PRINT '--- Status after Audit Return (expect Status=Returned, CurrentStage=Return from Audit) ---';
EXEC dbo.wf_GetWorkflowInstanceStatus @WorkflowInstanceId = @InstanceId;

-- Leasing officer re-approves the returned item
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @LeasingOfficer, @ActorRoleCodes = @LeasingRoles,
    @Action = 'Approve', @Comments = 'Docs attached, resubmitting',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
PRINT 'Return-from-Audit re-approved. NeedsRouting=' + CAST(@NeedsRouting AS CHAR(1));

SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @RoutingFromStageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @LeasingOfficer;

PRINT '--- Status after resume (expect CurrentStage = Under Audit Approval, NOT Finance/CC gate) ---';
EXEC dbo.wf_GetWorkflowInstanceStatus @WorkflowInstanceId = @InstanceId;

PRINT '--- Pending tasks now (expect exactly one Audit task, no fresh Finance/CC tasks) ---';
SELECT ApprovalTaskId, AssignedToRoleCode, Status FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId ORDER BY CreatedAt;

-- Auditor approves for real this time -> Finance Clearance -> Cleared
SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @Auditor, @ActorRoleCodes = @AuditorRoles,
    @Action = 'Approve', @Comments = 'Docs verified',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @RoutingFromStageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @Auditor;
PRINT 'Audit approved -> Finance Clearance';

SELECT TOP 1 @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @InstanceId AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @FinanceUser, @ActorRoleCodes = @FinanceRoles,
    @Action = 'Approve', @Comments = 'Cleared',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFromStageId OUTPUT;
SELECT TOP 1 @ToStageId = ToStageId FROM dbo.wf_Transition WHERE FromStageId = @RoutingFromStageId AND IsDefault = 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @InstanceId, @ToStageId = @ToStageId, @ActorUserId = @FinanceUser;
PRINT 'Finance Clearance -> Cleared';

PRINT '--- Final status (expect Status = Approved, stage = Cleared) ---';
EXEC dbo.wf_GetWorkflowInstanceStatus @WorkflowInstanceId = @InstanceId;

PRINT '--- Full audit trail ---';
EXEC dbo.wf_GetWorkflowInstanceHistory @WorkflowInstanceId = @InstanceId;
