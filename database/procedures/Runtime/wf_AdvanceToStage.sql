-- Mechanical stage transition: closes the current stage, opens the next
-- one(s), and creates tasks or completes the instance. The *decision* of
-- which stage to move to is made in .NET (NCalc against wf_Transition
-- candidates) -- this proc just executes an already-resolved move.
CREATE OR ALTER PROCEDURE dbo.wf_AdvanceToStage
    @WorkflowInstanceId UNIQUEIDENTIFIER,
    @ToStageId          INT,
    @ActorUserId        UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRAN;

    DECLARE @FromInstanceStageId BIGINT, @FromStageId INT;
    SELECT TOP 1 @FromInstanceStageId = InstanceStageId, @FromStageId = StageId
    FROM dbo.wf_WorkflowInstanceStage
    WHERE WorkflowInstanceId = @WorkflowInstanceId AND Status = 'Active'
    ORDER BY InstanceStageId DESC;

    IF @FromInstanceStageId IS NOT NULL
        UPDATE dbo.wf_WorkflowInstanceStage
        SET Status = 'Approved', ExitedAt = SYSUTCDATETIME()
        WHERE InstanceStageId = @FromInstanceStageId;

    DECLARE @StageType VARCHAR(20), @IsFinal BIT, @ContainerParallelGroupId INT;
    SELECT @StageType = StageType, @IsFinal = IsFinal, @ContainerParallelGroupId = ParallelGroupId
    FROM dbo.wf_Stage WHERE StageId = @ToStageId;

    DECLARE @AttemptNumber INT;
    SELECT @AttemptNumber = ISNULL(MAX(AttemptNumber), 0) + 1
    FROM dbo.wf_WorkflowInstanceStage WHERE WorkflowInstanceId = @WorkflowInstanceId AND StageId = @ToStageId;

    DECLARE @NewInstanceStageId BIGINT;
    INSERT INTO dbo.wf_WorkflowInstanceStage (WorkflowInstanceId, StageId, ParallelGroupId, Status, AttemptNumber)
    VALUES (@WorkflowInstanceId, @ToStageId, @ContainerParallelGroupId, 'Active', @AttemptNumber);
    SET @NewInstanceStageId = SCOPE_IDENTITY();

    UPDATE dbo.wf_WorkflowInstance SET CurrentStageId = @ToStageId WHERE WorkflowInstanceId = @WorkflowInstanceId;

    INSERT INTO dbo.wf_ApprovalAction (WorkflowInstanceId, InstanceStageId, ActionType, ActorUserId, OldStageId, NewStageId, OldStatus, NewStatus)
    VALUES (@WorkflowInstanceId, @NewInstanceStageId, 'SystemAdvance', @ActorUserId, @FromStageId, @ToStageId, 'InProgress',
            CASE WHEN @IsFinal = 1 THEN 'Completed' ELSE 'InProgress' END);

    IF @StageType = 'End'
    BEGIN
        UPDATE dbo.wf_WorkflowInstanceStage SET Status = 'Approved', ExitedAt = SYSUTCDATETIME() WHERE InstanceStageId = @NewInstanceStageId;
        UPDATE dbo.wf_WorkflowInstance SET Status = 'Approved', CompletedAt = SYSUTCDATETIME() WHERE WorkflowInstanceId = @WorkflowInstanceId;
    END
    ELSE IF @StageType = 'ParallelGroup'
    BEGIN
        -- Fan out: create an Active stage visit + tasks for every sibling branch.
        -- The container itself gets no tasks; it stays Active until
        -- wf_TryCompleteParallelGroup marks it Approved.
        DECLARE @BranchStageId INT, @BranchAttempt INT, @BranchInstanceStageId BIGINT;

        DECLARE branchCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT StageId FROM dbo.wf_Stage
            WHERE ParallelGroupId = @ContainerParallelGroupId AND StageType = 'Approval';

        OPEN branchCursor;
        FETCH NEXT FROM branchCursor INTO @BranchStageId;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @BranchAttempt = ISNULL(MAX(AttemptNumber), 0) + 1
            FROM dbo.wf_WorkflowInstanceStage WHERE WorkflowInstanceId = @WorkflowInstanceId AND StageId = @BranchStageId;

            INSERT INTO dbo.wf_WorkflowInstanceStage (WorkflowInstanceId, StageId, ParallelGroupId, Status, AttemptNumber)
            VALUES (@WorkflowInstanceId, @BranchStageId, @ContainerParallelGroupId, 'Active', @BranchAttempt);
            SET @BranchInstanceStageId = SCOPE_IDENTITY();

            EXEC dbo.wf_CreateTasksForStage @InstanceStageId = @BranchInstanceStageId;

            FETCH NEXT FROM branchCursor INTO @BranchStageId;
        END
        CLOSE branchCursor;
        DEALLOCATE branchCursor;
    END
    ELSE IF @StageType = 'Approval'
    BEGIN
        EXEC dbo.wf_CreateTasksForStage @InstanceStageId = @NewInstanceStageId;
    END
    -- StageType = 'Start' needs no tasks; it is only re-entered via
    -- wf_ActOnTask's Return branch, which inserts its own stage visit directly.

    COMMIT TRAN;
END
GO
