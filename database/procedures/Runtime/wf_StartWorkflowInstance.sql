CREATE OR ALTER PROCEDURE dbo.wf_StartWorkflowInstance
    @WorkflowDefinitionCode VARCHAR(50),
    @BusinessEntityType     VARCHAR(100),
    @BusinessEntityId       NVARCHAR(100),
    @ContextDataJson        NVARCHAR(MAX) = NULL,
    @StartedByUserId        UNIQUEIDENTIFIER,
    @WorkflowInstanceId     UNIQUEIDENTIFIER OUTPUT,
    @InitialStageId         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WorkflowVersionId INT;

    SELECT @WorkflowVersionId = v.WorkflowVersionId
    FROM dbo.wf_WorkflowVersion v
    INNER JOIN dbo.wf_WorkflowDefinition d ON d.WorkflowDefinitionId = v.WorkflowDefinitionId
    WHERE d.Code = @WorkflowDefinitionCode AND v.Status = 'Published' AND d.IsActive = 1;

    IF @WorkflowVersionId IS NULL
        THROW 51001, 'No published workflow version found for the given definition code.', 1;

    SELECT @InitialStageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @WorkflowVersionId AND IsInitial = 1;
    IF @InitialStageId IS NULL
        THROW 51002, 'Workflow version has no initial stage configured.', 1;

    SET @WorkflowInstanceId = NEWID();

    BEGIN TRAN;

    INSERT INTO dbo.wf_WorkflowInstance
        (WorkflowInstanceId, WorkflowVersionId, BusinessEntityType, BusinessEntityId, CurrentStageId, Status, ContextDataJson, StartedByUserId)
    VALUES
        (@WorkflowInstanceId, @WorkflowVersionId, @BusinessEntityType, @BusinessEntityId, @InitialStageId, 'InProgress', @ContextDataJson, @StartedByUserId);

    DECLARE @InstanceStageId BIGINT;
    INSERT INTO dbo.wf_WorkflowInstanceStage (WorkflowInstanceId, StageId, Status, AttemptNumber)
    VALUES (@WorkflowInstanceId, @InitialStageId, 'Active', 1);
    SET @InstanceStageId = SCOPE_IDENTITY();

    INSERT INTO dbo.wf_ApprovalAction (WorkflowInstanceId, InstanceStageId, ActionType, ActorUserId, NewStatus, NewStageId, ContextSnapshotJson)
    VALUES (@WorkflowInstanceId, @InstanceStageId, 'Submit', @StartedByUserId, 'InProgress', @InitialStageId, @ContextDataJson);

    -- The initial stage never carries approval rules, so no tasks are created
    -- here. Advancing past it (resolving routing via NCalc, then calling
    -- wf_AdvanceToStage) is the caller's responsibility.
    COMMIT TRAN;
END
GO
