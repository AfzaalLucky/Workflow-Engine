CREATE OR ALTER PROCEDURE dbo.wf_UpsertApprovalGroupMember
    @ApprovalGroupId       INT,
    @MemberType            VARCHAR(10),
    @UserId                UNIQUEIDENTIFIER = NULL,
    @RoleCode              VARCHAR(50) = NULL,
    @IsActive              BIT = 1,
    @ActorUserId           UNIQUEIDENTIFIER,
    @ApprovalGroupMemberId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @ApprovalGroupMemberId = ApprovalGroupMemberId
    FROM dbo.wf_ApprovalGroupMember
    WHERE ApprovalGroupId = @ApprovalGroupId AND MemberType = @MemberType
      AND ((@MemberType = 'User' AND UserId = @UserId) OR (@MemberType = 'Role' AND RoleCode = @RoleCode));

    IF @ApprovalGroupMemberId IS NULL
    BEGIN
        INSERT INTO dbo.wf_ApprovalGroupMember (ApprovalGroupId, MemberType, UserId, RoleCode, IsActive)
        VALUES (@ApprovalGroupId, @MemberType, @UserId, @RoleCode, @IsActive);
        SET @ApprovalGroupMemberId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.wf_ApprovalGroupMember SET IsActive = @IsActive WHERE ApprovalGroupMemberId = @ApprovalGroupMemberId;
    END

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId)
    VALUES ('ApprovalGroupMember', CAST(@ApprovalGroupMemberId AS NVARCHAR(20)), 'Upsert', @ActorUserId);
END
GO
