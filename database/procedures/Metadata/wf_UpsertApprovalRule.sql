CREATE OR ALTER PROCEDURE dbo.wf_UpsertApprovalRule
    @ApprovalRuleId       INT = NULL,
    @StageId              INT,
    @ApproverType         VARCHAR(10),
    @SpecificUserId       UNIQUEIDENTIFIER = NULL,
    @ApproverRoleCode     VARCHAR(50) = NULL,
    @ApprovalGroupId      INT = NULL,
    @RequiredCount        INT = 1,
    @ActorUserId          UNIQUEIDENTIFIER,
    @ResultApprovalRuleId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @ApprovalRuleId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.wf_ApprovalRule WHERE ApprovalRuleId = @ApprovalRuleId)
    BEGIN
        UPDATE dbo.wf_ApprovalRule
        SET StageId = @StageId, ApproverType = @ApproverType, SpecificUserId = @SpecificUserId,
            ApproverRoleCode = @ApproverRoleCode, ApprovalGroupId = @ApprovalGroupId, RequiredCount = @RequiredCount
        WHERE ApprovalRuleId = @ApprovalRuleId;
        SET @ResultApprovalRuleId = @ApprovalRuleId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.wf_ApprovalRule (StageId, ApproverType, SpecificUserId, ApproverRoleCode, ApprovalGroupId, RequiredCount)
        VALUES (@StageId, @ApproverType, @SpecificUserId, @ApproverRoleCode, @ApprovalGroupId, @RequiredCount);
        SET @ResultApprovalRuleId = SCOPE_IDENTITY();
    END

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId)
    VALUES ('ApprovalRule', CAST(@ResultApprovalRuleId AS NVARCHAR(20)), 'Upsert', @ActorUserId);
END
GO
