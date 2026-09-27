-- Claims a batch of due outbox events for delivery. READPAST lets several
-- API instances poll concurrently without double-claiming; the lease
-- (NextAttemptAt pushed forward) makes a claim expire if the claimer dies.
--
-- Ordering guarantee: an event is only claimable when no earlier event for
-- the same instance is still Pending, so consumers see each instance's
-- events strictly in order (StageEntered 20 can never overwrite a later
-- InstanceApproved). A dead-lettered (Failed) event stops blocking.
CREATE OR ALTER PROCEDURE dbo.wf_ClaimWorkflowEvents
    @BatchSize    INT = 50,
    @LeaseSeconds INT = 60
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2(3) = SYSUTCDATETIME();

    WITH due AS (
        SELECT TOP (@BatchSize) e.EventId, e.WorkflowInstanceId, e.EventType, e.PayloadJson, e.AttemptCount, e.NextAttemptAt
        FROM dbo.wf_WorkflowEvent e WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE e.Status = 'Pending'
          AND e.NextAttemptAt <= @Now
          AND NOT EXISTS (
              SELECT 1 FROM dbo.wf_WorkflowEvent prior
              WHERE prior.WorkflowInstanceId = e.WorkflowInstanceId
                AND prior.Status = 'Pending'
                AND prior.EventId < e.EventId
          )
        ORDER BY e.EventId
    )
    UPDATE due
    SET AttemptCount = AttemptCount + 1,
        NextAttemptAt = DATEADD(SECOND, @LeaseSeconds, @Now)
    OUTPUT inserted.EventId, inserted.WorkflowInstanceId, inserted.EventType, inserted.PayloadJson, inserted.AttemptCount;
END
GO
