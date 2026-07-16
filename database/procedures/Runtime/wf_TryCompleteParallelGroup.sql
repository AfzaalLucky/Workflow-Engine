-- Evaluates whether a parallel group's join condition (All/AnyOne/AnyN) is
-- now satisfied for one instance; if so, cancels any still-pending sibling
-- branches and marks the container's stage visit Approved.
CREATE OR ALTER PROCEDURE dbo.wf_TryCompleteParallelGroup
    @ParallelGroupId    INT,
    @WorkflowInstanceId UNIQUEIDENTIFIER,
    @ActorUserId        UNIQUEIDENTIFIER,
    @Completed          BIT OUTPUT,
    @ContainerStageId   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @JoinType VARCHAR(20), @MinRequiredApprovals INT;
    SELECT @JoinType = JoinType, @MinRequiredApprovals = MinRequiredApprovals
    FROM dbo.wf_ParallelGroup WHERE ParallelGroupId = @ParallelGroupId;

    SELECT @ContainerStageId = StageId FROM dbo.wf_Stage
    WHERE ParallelGroupId = @ParallelGroupId AND StageType = 'ParallelGroup';

    -- Latest (highest InstanceStageId) non-superseded visit per branch stage.
    DECLARE @Branches TABLE (StageId INT, InstanceStageId BIGINT, Status VARCHAR(20));
    INSERT INTO @Branches (StageId, InstanceStageId, Status)
    SELECT wis.StageId, wis.InstanceStageId, wis.Status
    FROM dbo.wf_WorkflowInstanceStage wis
    INNER JOIN (
        SELECT StageId, MAX(InstanceStageId) AS MaxInstanceStageId
        FROM dbo.wf_WorkflowInstanceStage
        WHERE WorkflowInstanceId = @WorkflowInstanceId
          AND StageId IN (SELECT StageId FROM dbo.wf_Stage WHERE ParallelGroupId = @ParallelGroupId AND StageType = 'Approval')
          AND Status <> 'Superseded'
        GROUP BY StageId
    ) latest ON latest.StageId = wis.StageId AND latest.MaxInstanceStageId = wis.InstanceStageId;

    DECLARE @TotalBranches INT, @ApprovedBranches INT;
    SELECT @TotalBranches = COUNT(*), @ApprovedBranches = SUM(CASE WHEN Status = 'Approved' THEN 1 ELSE 0 END) FROM @Branches;

    SET @Completed = CASE
        WHEN @JoinType = 'All'    AND @ApprovedBranches = @TotalBranches THEN 1
        WHEN @JoinType = 'AnyOne' AND @ApprovedBranches >= 1 THEN 1
        WHEN @JoinType = 'AnyN'   AND @ApprovedBranches >= @MinRequiredApprovals THEN 1
        ELSE 0
    END;

    IF @Completed = 1
    BEGIN
        UPDATE wis
        SET Status = 'Cancelled', ExitedAt = SYSUTCDATETIME()
        FROM dbo.wf_WorkflowInstanceStage wis
        INNER JOIN @Branches b ON b.InstanceStageId = wis.InstanceStageId
        WHERE b.Status = 'Active';

        UPDATE t
        SET Status = 'Cancelled'
        FROM dbo.wf_ApprovalTask t
        INNER JOIN @Branches b ON b.InstanceStageId = t.InstanceStageId
        WHERE b.Status = 'Active' AND t.Status = 'Pending';

        DECLARE @ContainerInstanceStageId BIGINT;
        SELECT TOP 1 @ContainerInstanceStageId = InstanceStageId
        FROM dbo.wf_WorkflowInstanceStage
        WHERE WorkflowInstanceId = @WorkflowInstanceId AND StageId = @ContainerStageId AND Status = 'Active'
        ORDER BY InstanceStageId DESC;

        UPDATE dbo.wf_WorkflowInstanceStage
        SET Status = 'Approved', ExitedAt = SYSUTCDATETIME()
        WHERE InstanceStageId = @ContainerInstanceStageId;

        INSERT INTO dbo.wf_ApprovalAction (WorkflowInstanceId, InstanceStageId, ActionType, ActorUserId, OldStatus, NewStatus, NewStageId)
        VALUES (@WorkflowInstanceId, @ContainerInstanceStageId, 'SystemAdvance', @ActorUserId, 'InProgress', 'Approved', @ContainerStageId);
    END
END
GO
