CREATE OR ALTER PROCEDURE dbo.wf_UpsertApprovalGroup
    @Code             VARCHAR(50),
    @Name             NVARCHAR(200),
    @IsActive         BIT = 1,
    @ActorUserId      UNIQUEIDENTIFIER,
    @ApprovalGroupId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @ApprovalGroupId = ApprovalGroupId FROM dbo.wf_ApprovalGroup WHERE Code = @Code;

    IF @ApprovalGroupId IS NULL
    BEGIN
        INSERT INTO dbo.wf_ApprovalGroup (Code, Name, IsActive) VALUES (@Code, @Name, @IsActive);
        SET @ApprovalGroupId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.wf_ApprovalGroup SET Name = @Name, IsActive = @IsActive WHERE ApprovalGroupId = @ApprovalGroupId;
    END

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId)
    VALUES ('ApprovalGroup', CAST(@ApprovalGroupId AS NVARCHAR(20)), 'Upsert', @ActorUserId);
END
GO
