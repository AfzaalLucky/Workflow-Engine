-- Internal helper: appends one lifecycle event to the wf_WorkflowEvent
-- outbox. Always called from inside the caller's transaction, so the event
-- exists if and only if the state change that caused it committed.
--
-- The payload is a self-contained snapshot, so consumers (in-process
-- handlers, webhooks in other systems) never need to query wf_* tables.
-- @StageId defaults to the instance's CurrentStageId.
CREATE OR ALTER PROCEDURE dbo.wf_EnqueueEvent
    @WorkflowInstanceId UNIQUEIDENTIFIER,
    @EventType          VARCHAR(50),  -- InstanceStarted | StageEntered | InstanceApproved | InstanceRejected | InstanceReturned | InstanceResumed | InstanceErrored
    @ActorUserId        UNIQUEIDENTIFIER,
    @StageId            INT = NULL,
    @Comments           NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PayloadJson NVARCHAR(MAX) = (
        SELECT
            @EventType              AS eventType,
            wi.WorkflowInstanceId   AS workflowInstanceId,
            d.Code                  AS workflowDefinitionCode,
            v.VersionNumber         AS workflowVersionNumber,
            wi.BusinessEntityType   AS businessEntityType,
            wi.BusinessEntityId     AS businessEntityId,
            wi.Status               AS instanceStatus,
            s.StageId               AS stageId,
            s.StageKey              AS stageKey,
            s.Name                  AS stageName,
            s.StageType             AS stageType,
            s.ExternalStatusCode    AS externalStatusCode,
            @ActorUserId            AS actorUserId,
            @Comments               AS comments,
            SYSUTCDATETIME()        AS occurredAt
        FROM dbo.wf_WorkflowInstance wi
        INNER JOIN dbo.wf_WorkflowVersion v ON v.WorkflowVersionId = wi.WorkflowVersionId
        INNER JOIN dbo.wf_WorkflowDefinition d ON d.WorkflowDefinitionId = v.WorkflowDefinitionId
        LEFT JOIN dbo.wf_Stage s ON s.StageId = ISNULL(@StageId, wi.CurrentStageId)
        WHERE wi.WorkflowInstanceId = @WorkflowInstanceId
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    );

    INSERT INTO dbo.wf_WorkflowEvent (WorkflowInstanceId, EventType, PayloadJson)
    VALUES (@WorkflowInstanceId, @EventType, @PayloadJson);
END
GO
