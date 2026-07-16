CREATE OR ALTER PROCEDURE dbo.wf_UpsertParallelGroup
    @WorkflowVersionId    INT,
    @Code                 VARCHAR(50),
    @Name                 NVARCHAR(200),
    @JoinType             VARCHAR(20) = 'All',
    @MinRequiredApprovals INT = NULL,
    @ActorUserId          UNIQUEIDENTIFIER,
    @ParallelGroupId      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @ParallelGroupId = ParallelGroupId FROM dbo.wf_ParallelGroup WHERE WorkflowVersionId = @WorkflowVersionId AND Code = @Code;

    IF @ParallelGroupId IS NULL
    BEGIN
        INSERT INTO dbo.wf_ParallelGroup (WorkflowVersionId, Code, Name, JoinType, MinRequiredApprovals)
        VALUES (@WorkflowVersionId, @Code, @Name, @JoinType, @MinRequiredApprovals);
        SET @ParallelGroupId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.wf_ParallelGroup
        SET Name = @Name, JoinType = @JoinType, MinRequiredApprovals = @MinRequiredApprovals
        WHERE ParallelGroupId = @ParallelGroupId;
    END

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId)
    VALUES ('ParallelGroup', CAST(@ParallelGroupId AS NVARCHAR(20)), 'Upsert', @ActorUserId);
END
GO
