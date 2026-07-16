CREATE OR ALTER PROCEDURE dbo.wf_UpsertStage
    @WorkflowVersionId INT,
    @StageKey          VARCHAR(50),
    @Name              NVARCHAR(200),
    @StageOrder        INT,
    @StageType         VARCHAR(20),
    @ParallelGroupId   INT = NULL,
    @IsInitial         BIT = 0,
    @IsFinal           BIT = 0,
    @ActorUserId       UNIQUEIDENTIFIER,
    @StageId           INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @StageId = StageId FROM dbo.wf_Stage WHERE WorkflowVersionId = @WorkflowVersionId AND StageKey = @StageKey;

    IF @StageId IS NULL
    BEGIN
        INSERT INTO dbo.wf_Stage (WorkflowVersionId, StageKey, Name, StageOrder, StageType, ParallelGroupId, IsInitial, IsFinal)
        VALUES (@WorkflowVersionId, @StageKey, @Name, @StageOrder, @StageType, @ParallelGroupId, @IsInitial, @IsFinal);
        SET @StageId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.wf_Stage
        SET Name = @Name, StageOrder = @StageOrder, StageType = @StageType,
            ParallelGroupId = @ParallelGroupId, IsInitial = @IsInitial, IsFinal = @IsFinal
        WHERE StageId = @StageId;
    END

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId)
    VALUES ('Stage', CAST(@StageId AS NVARCHAR(20)), 'Upsert', @ActorUserId);
END
GO
