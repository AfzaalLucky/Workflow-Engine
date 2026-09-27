-- =============================================================
-- Verifies the generic-engine features on a self-seeded workflow
-- (GENERIC_TEST), independent of any business module:
--   1. N-of-M group approval (RequiredCount=2 of 3 members)
--   2. ReturnToOrigin resume without a dedicated per-origin stage
--   3. Return from a parallel branch: siblings closed, resumes at the gate
--   4. Reject from a parallel branch: no orphaned pending tasks
--   5. Errored instance recovery via resume
--   6. Outbox: events written, strict per-instance claim ordering
-- Every check THROWs on failure, so `sqlcmd -b` exits non-zero.
-- Run after 00_deploy_all.sql (or 01_upgrade_existing.sql).
-- =============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Admin UNIQUEIDENTIFIER = 'CCCCCCCC-0000-0000-0000-000000000000';
DECLARE @U1 UNIQUEIDENTIFIER = 'CCCCCCCC-0000-0000-0000-000000000001';
DECLARE @U2 UNIQUEIDENTIFIER = 'CCCCCCCC-0000-0000-0000-000000000002';
DECLARE @U3 UNIQUEIDENTIFIER = 'CCCCCCCC-0000-0000-0000-000000000003';
DECLARE @NoRoles dbo.wf_RoleCodeList;
DECLARE @ReviewerRoles dbo.wf_RoleCodeList; INSERT INTO @ReviewerRoles VALUES ('GT_Reviewer');
DECLARE @BranchARoles dbo.wf_RoleCodeList; INSERT INTO @BranchARoles VALUES ('GT_BranchA');
DECLARE @BranchBRoles dbo.wf_RoleCodeList; INSERT INTO @BranchBRoles VALUES ('GT_BranchB');
DECLARE @FinalRoles dbo.wf_RoleCodeList; INSERT INTO @FinalRoles VALUES ('GT_Final');

---------------------------------------------------------------
-- Seed: START -> REVIEW -> BOARD (2 of 3) -> GATE(A || B) -> FINAL -> END
---------------------------------------------------------------
DECLARE @DefId INT, @VerId INT, @PgId INT, @GroupId INT,
        @Start INT, @Review INT, @Board INT, @Gate INT, @BranchA INT, @BranchB INT, @Final INT, @End INT;

IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowDefinition WHERE Code = 'GENERIC_TEST')
BEGIN
    INSERT INTO dbo.wf_WorkflowDefinition (Code, Name) VALUES ('GENERIC_TEST', 'Generic engine feature test');
    SET @DefId = SCOPE_IDENTITY();
    INSERT INTO dbo.wf_WorkflowVersion (WorkflowDefinitionId, VersionNumber, Status, PublishedAt) VALUES (@DefId, 1, 'Published', SYSUTCDATETIME());
    SET @VerId = SCOPE_IDENTITY();

    INSERT INTO dbo.wf_ParallelGroup (WorkflowVersionId, Code, Name, JoinType) VALUES (@VerId, 'GT_GATE', 'Gate', 'All');
    SET @PgId = SCOPE_IDENTITY();

    INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, ParallelGroupId, IsInitial, IsFinal, ExternalStatusCode) VALUES
        (@VerId, 'START',  'Start',    10, 'Start',         NULL,  1, 0, 'S0'),
        (@VerId, 'REVIEW', 'Review',   20, 'Approval',      NULL,  0, 0, 'S20'),
        (@VerId, 'BOARD',  'Board',    30, 'Approval',      NULL,  0, 0, 'S30'),
        (@VerId, 'GATE',   'Gate',     40, 'ParallelGroup', @PgId, 0, 0, 'S40'),
        (@VerId, 'A',      'Branch A', 40, 'Approval',      @PgId, 0, 0, 'S41'),
        (@VerId, 'B',      'Branch B', 40, 'Approval',      @PgId, 0, 0, 'S42'),
        (@VerId, 'FINAL',  'Final',    50, 'Approval',      NULL,  0, 0, 'S50'),
        (@VerId, 'END',    'Done',     60, 'End',           NULL,  0, 1, 'S99');
END
ELSE
    SELECT @VerId = v.WorkflowVersionId FROM dbo.wf_WorkflowVersion v
    INNER JOIN dbo.wf_WorkflowDefinition d ON d.WorkflowDefinitionId = v.WorkflowDefinitionId
    WHERE d.Code = 'GENERIC_TEST' AND v.Status = 'Published';

SELECT @Start = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'START';
SELECT @Review = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'REVIEW';
SELECT @Board = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'BOARD';
SELECT @Gate = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'GATE';
SELECT @BranchA = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'A';
SELECT @BranchB = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'B';
SELECT @Final = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'FINAL';
SELECT @End = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @VerId AND StageKey = 'END';

IF NOT EXISTS (SELECT 1 FROM dbo.wf_Transition WHERE WorkflowVersionId = @VerId)
BEGIN
    INSERT INTO dbo.wf_Transition (WorkflowVersionId, FromStageId, ToStageId, IsDefault) VALUES
        (@VerId, @Start, @Review, 1), (@VerId, @Review, @Board, 1), (@VerId, @Board, @Gate, 1),
        (@VerId, @Gate, @Final, 1), (@VerId, @Final, @End, 1);

    INSERT INTO dbo.wf_ApprovalGroup (Code, Name) VALUES ('GT_BOARD', 'Test board');
    SET @GroupId = SCOPE_IDENTITY();
    INSERT INTO dbo.wf_ApprovalGroupMember (ApprovalGroupId, MemberType, UserId) VALUES
        (@GroupId, 'User', @U1), (@GroupId, 'User', @U2), (@GroupId, 'User', @U3);

    INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, ApproverRoleCode, ApprovalGroupId, RequiredCount) VALUES
        (@Review,  'Role',  'GT_Reviewer', NULL, 1),
        (@Board,   'Group', NULL,          @GroupId, 2),
        (@BranchA, 'Role',  'GT_BranchA',  NULL, 1),
        (@BranchB, 'Role',  'GT_BranchB',  NULL, 1),
        (@Final,   'Role',  'GT_Final',    NULL, 1);

    -- No dedicated "return from X" stages: REVIEW is the single rework
    -- stage, and ReturnToOrigin sends each return back where it came from.
    INSERT INTO dbo.wf_ReturnRule (FromStageId, ToStageId, ResetApprovalsOnReturn, RequireComment, ResumeMode) VALUES
        (@Final,   @Review, 0, 1, 'ReturnToOrigin'),
        (@BranchB, @Review, 0, 1, 'ReturnToOrigin');
END

DECLARE @Inst UNIQUEIDENTIFIER, @Initial INT, @TaskId BIGINT, @WiId UNIQUEIDENTIFIER,
        @NeedsRouting BIT, @RoutingFrom INT, @ResumeTo INT, @Count INT, @Msg NVARCHAR(400);

---------------------------------------------------------------
PRINT '--- 1. N-of-M group approval ---';
---------------------------------------------------------------
EXEC dbo.wf_StartWorkflowInstance @WorkflowDefinitionCode = 'GENERIC_TEST', @BusinessEntityType = 'GenericTest',
    @BusinessEntityId = 'GT-1', @StartedByUserId = @Admin, @WorkflowInstanceId = @Inst OUTPUT, @InitialStageId = @Initial OUTPUT;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst, @ToStageId = @Review, @ActorUserId = @Admin;

SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U1, @ActorRoleCodes = @ReviewerRoles, @Action = 'Approve',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst, @ToStageId = @Board, @ActorUserId = @U1;

SELECT @Count = COUNT(*) FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND Status = 'Pending';
IF @Count <> 3 THROW 60001, 'Expected 3 board tasks (one per member).', 1;

SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND Status = 'Pending' AND AssignedToUserId = @U1;
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U1, @ActorRoleCodes = @NoRoles, @Action = 'Approve',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
IF @NeedsRouting <> 0 THROW 60002, '1 of 2 required approvals must not complete the stage.', 1;

SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND Status = 'Pending' AND AssignedToUserId = @U2;
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U2, @ActorRoleCodes = @NoRoles, @Action = 'Approve',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
IF @NeedsRouting <> 1 OR @RoutingFrom <> @Board THROW 60003, '2 of 3 approvals must complete the board stage.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND AssignedToUserId = @U3 AND Status = 'Cancelled')
    THROW 60004, 'Third member task should be cancelled once quorum is reached.', 1;
PRINT 'OK: 2-of-3 quorum completes the stage and cancels the leftover task';

---------------------------------------------------------------
PRINT '--- 2. ReturnToOrigin from a normal stage ---';
---------------------------------------------------------------
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst, @ToStageId = @Gate, @ActorUserId = @U2;
SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND Status = 'Pending' AND AssignedToRoleCode = 'GT_BranchA';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U1, @ActorRoleCodes = @BranchARoles, @Action = 'Approve',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND Status = 'Pending' AND AssignedToRoleCode = 'GT_BranchB';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U1, @ActorRoleCodes = @BranchBRoles, @Action = 'Approve',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
IF @NeedsRouting <> 1 OR @RoutingFrom <> @Gate OR @ResumeTo IS NOT NULL THROW 60010, 'Gate should complete with normal (non-resume) routing.', 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst, @ToStageId = @Final, @ActorUserId = @U1;

SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U3, @ActorRoleCodes = @FinalRoles, @Action = 'Return',
    @Comments = 'Please fix', @ReturnToStageId = @Review,
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;

SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U1, @ActorRoleCodes = @ReviewerRoles, @Action = 'Approve',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
IF @NeedsRouting <> 1 OR ISNULL(@ResumeTo, -1) <> @Final
BEGIN
    SET @Msg = CONCAT('Re-approved REVIEW should resume to FINAL (', @Final, '), got ', ISNULL(CAST(@ResumeTo AS VARCHAR(10)), 'NULL'), '.');
    THROW 60011, @Msg, 1;
END
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst, @ToStageId = @ResumeTo, @ActorUserId = @U1;

SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U3, @ActorRoleCodes = @FinalRoles, @Action = 'Approve',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
IF @ResumeTo IS NOT NULL THROW 60012, 'A normally-entered stage must not carry a resume target.', 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst, @ToStageId = @End, @ActorUserId = @U3;
IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowInstance WHERE WorkflowInstanceId = @Inst AND Status = 'Approved')
    THROW 60013, 'Instance 1 should be Approved.', 1;
PRINT 'OK: FINAL -> return -> REVIEW -> straight back to FINAL (board and gate skipped) -> Approved';

---------------------------------------------------------------
PRINT '--- 6. Outbox events for instance 1 ---';
---------------------------------------------------------------
DECLARE @Events NVARCHAR(MAX) = (SELECT STRING_AGG(EventType, ',') WITHIN GROUP (ORDER BY EventId) FROM dbo.wf_WorkflowEvent WHERE WorkflowInstanceId = @Inst);
PRINT @Events;
IF @Events <> 'InstanceStarted,StageEntered,StageEntered,StageEntered,StageEntered,InstanceReturned,StageEntered,InstanceApproved'
    THROW 60060, 'Unexpected event sequence for instance 1.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowEvent WHERE WorkflowInstanceId = @Inst AND EventType = 'InstanceApproved'
               AND JSON_VALUE(PayloadJson, '$.externalStatusCode') = 'S99' AND JSON_VALUE(PayloadJson, '$.businessEntityId') = 'GT-1')
    THROW 60061, 'InstanceApproved payload should carry the End stage ExternalStatusCode and business key.', 1;

DECLARE @Claimed TABLE (EventId BIGINT, WorkflowInstanceId UNIQUEIDENTIFIER, EventType VARCHAR(50), PayloadJson NVARCHAR(MAX), AttemptCount INT);
INSERT INTO @Claimed EXEC dbo.wf_ClaimWorkflowEvents @BatchSize = 1000, @LeaseSeconds = 60;
IF EXISTS (SELECT WorkflowInstanceId FROM @Claimed GROUP BY WorkflowInstanceId HAVING COUNT(*) > 1)
    THROW 60062, 'Claim must return at most one event per instance (ordering guarantee).', 1;
IF NOT EXISTS (SELECT 1 FROM @Claimed WHERE WorkflowInstanceId = @Inst AND EventType = 'InstanceStarted')
    THROW 60063, 'The first claimable event for instance 1 must be InstanceStarted.', 1;

DECLARE @FirstEventId BIGINT = (SELECT EventId FROM @Claimed WHERE WorkflowInstanceId = @Inst);
EXEC dbo.wf_CompleteWorkflowEvent @EventId = @FirstEventId, @Succeeded = 0, @Error = 'handler down', @RetryDelaySeconds = 0;
IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowEvent WHERE EventId = @FirstEventId AND Status = 'Pending' AND AttemptCount = 1 AND LastError = 'handler down')
    THROW 60064, 'A failed delivery should stay Pending with the error recorded.', 1;
EXEC dbo.wf_CompleteWorkflowEvent @EventId = @FirstEventId, @Succeeded = 1;
IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowEvent WHERE EventId = @FirstEventId AND Status = 'Delivered')
    THROW 60065, 'Event should be Delivered.', 1;
-- Release the other leases so later runs / the API dispatcher are unaffected.
UPDATE e SET NextAttemptAt = SYSUTCDATETIME(), AttemptCount = e.AttemptCount - 1
FROM dbo.wf_WorkflowEvent e INNER JOIN @Claimed c ON c.EventId = e.EventId WHERE e.EventId <> @FirstEventId;
PRINT 'OK: event sequence, payload, per-instance claim ordering, retry and delivery';

---------------------------------------------------------------
PRINT '--- 3. Return from a parallel branch ---';
---------------------------------------------------------------
DECLARE @Inst2 UNIQUEIDENTIFIER;
EXEC dbo.wf_StartWorkflowInstance @WorkflowDefinitionCode = 'GENERIC_TEST', @BusinessEntityType = 'GenericTest',
    @BusinessEntityId = 'GT-2', @StartedByUserId = @Admin, @WorkflowInstanceId = @Inst2 OUTPUT, @InitialStageId = @Initial OUTPUT;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst2, @ToStageId = @Gate, @ActorUserId = @Admin; -- jump straight to the gate

SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst2 AND Status = 'Pending' AND AssignedToRoleCode = 'GT_BranchB';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U2, @ActorRoleCodes = @BranchBRoles, @Action = 'Return',
    @Comments = 'Need more info', @ReturnToStageId = @Review,
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;

IF EXISTS (SELECT 1 FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst2 AND Status = 'Pending' AND AssignedToRoleCode = 'GT_BranchA')
    THROW 60020, 'Sibling branch A task must be cancelled when branch B returns.', 1;
SELECT @Count = COUNT(*) FROM dbo.wf_WorkflowInstanceStage WHERE WorkflowInstanceId = @Inst2 AND Status = 'Active';
IF @Count <> 1 THROW 60021, 'Only the return-target stage visit should remain Active.', 1;

SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst2 AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U1, @ActorRoleCodes = @ReviewerRoles, @Action = 'Approve',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
IF ISNULL(@ResumeTo, -1) <> @Gate THROW 60022, 'A return from a branch should resume at the gate container.', 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst2, @ToStageId = @ResumeTo, @ActorUserId = @U1;
SELECT @Count = COUNT(*) FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst2 AND Status = 'Pending';
IF @Count <> 2 THROW 60023, 'Re-entering the gate should fan out both branches again.', 1;
PRINT 'OK: branch return closes siblings, resumes at the gate, gate re-fans out';

---------------------------------------------------------------
PRINT '--- 4. Reject from a parallel branch ---';
---------------------------------------------------------------
SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst2 AND Status = 'Pending' AND AssignedToRoleCode = 'GT_BranchA';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U1, @ActorRoleCodes = @BranchARoles, @Action = 'Reject', @Comments = 'No',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
IF EXISTS (SELECT 1 FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst2 AND Status = 'Pending')
    THROW 60030, 'A rejected instance must have no pending tasks left in anyone''s inbox.', 1;
IF EXISTS (SELECT 1 FROM dbo.wf_WorkflowInstanceStage WHERE WorkflowInstanceId = @Inst2 AND Status = 'Active')
    THROW 60031, 'A rejected instance must have no active stage visits.', 1;
PRINT 'OK: branch reject leaves no orphaned tasks or active visits';

---------------------------------------------------------------
PRINT '--- 5. Errored instance recovery ---';
---------------------------------------------------------------
DECLARE @Inst3 UNIQUEIDENTIFIER, @CurrentStage INT;
EXEC dbo.wf_StartWorkflowInstance @WorkflowDefinitionCode = 'GENERIC_TEST', @BusinessEntityType = 'GenericTest',
    @BusinessEntityId = 'GT-3', @StartedByUserId = @Admin, @WorkflowInstanceId = @Inst3 OUTPUT, @InitialStageId = @Initial OUTPUT;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst3, @ToStageId = @Review, @ActorUserId = @Admin;
SELECT @TaskId = ApprovalTaskId FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst3 AND Status = 'Pending';
EXEC dbo.wf_ActOnTask @ApprovalTaskId = @TaskId, @ActorUserId = @U1, @ActorRoleCodes = @ReviewerRoles, @Action = 'Approve',
    @WorkflowInstanceId = @WiId OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @RoutingFromStageId = @RoutingFrom OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
-- Simulate the .NET router failing here (e.g. a bad NCalc condition).
EXEC dbo.wf_MarkInstanceErrored @WorkflowInstanceId = @Inst3, @ActorUserId = @U1, @ErrorMessage = 'No transition matched';
IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowInstance WHERE WorkflowInstanceId = @Inst3 AND Status = 'Errored')
    THROW 60040, 'Instance should be Errored.', 1;

EXEC dbo.wf_ResumeWorkflowInstance @WorkflowInstanceId = @Inst3, @ActorUserId = @Admin,
    @CurrentStageId = @CurrentStage OUTPUT, @NeedsRouting = @NeedsRouting OUTPUT, @ResumeToStageId = @ResumeTo OUTPUT;
IF @NeedsRouting <> 1 OR @CurrentStage <> @Review THROW 60041, 'Errored resume should re-route from the satisfied stage, not reopen it.', 1;
IF EXISTS (SELECT 1 FROM dbo.wf_ApprovalTask WHERE WorkflowInstanceId = @Inst3 AND Status = 'Pending')
    THROW 60042, 'Errored resume must not recreate tasks on the already-approved stage.', 1;
EXEC dbo.wf_AdvanceToStage @WorkflowInstanceId = @Inst3, @ToStageId = @Board, @ActorUserId = @Admin;
IF NOT EXISTS (SELECT 1 FROM dbo.wf_WorkflowInstance WHERE WorkflowInstanceId = @Inst3 AND Status = 'InProgress' AND CurrentStageId = @Board)
    THROW 60043, 'Recovered instance should be InProgress at BOARD.', 1;
PRINT 'OK: Errored -> resume -> re-routed without re-approval';

PRINT '=== ALL GENERIC ENGINE CHECKS PASSED ===';
