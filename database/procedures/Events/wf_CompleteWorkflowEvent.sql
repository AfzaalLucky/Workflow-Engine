-- Records the outcome of one delivery attempt. Failures are retried with
-- exponential backoff (RetryDelaySeconds * 2^(attempt-1), capped at 1h)
-- until MaxAttempts, then dead-lettered as Failed for manual inspection.
CREATE OR ALTER PROCEDURE dbo.wf_CompleteWorkflowEvent
    @EventId           BIGINT,
    @Succeeded         BIT,
    @Error             NVARCHAR(2000) = NULL,
    @MaxAttempts       INT = 10,
    @RetryDelaySeconds INT = 15
AS
BEGIN
    SET NOCOUNT ON;

    IF @Succeeded = 1
    BEGIN
        UPDATE dbo.wf_WorkflowEvent
        SET Status = 'Delivered', DeliveredAt = SYSUTCDATETIME(), LastError = NULL
        WHERE EventId = @EventId;
        RETURN;
    END

    UPDATE dbo.wf_WorkflowEvent
    SET LastError = @Error,
        Status = CASE WHEN AttemptCount >= @MaxAttempts THEN 'Failed' ELSE 'Pending' END,
        NextAttemptAt = DATEADD(SECOND,
            CASE WHEN AttemptCount >= 9 THEN 3600
                 ELSE IIF(@RetryDelaySeconds * POWER(2, AttemptCount - 1) > 3600, 3600, @RetryDelaySeconds * POWER(2, AttemptCount - 1))
            END,
            SYSUTCDATETIME())
    WHERE EventId = @EventId;
END
GO
