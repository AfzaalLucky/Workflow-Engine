CREATE OR ALTER PROCEDURE dbo.wf_UpsertReturnRule
    @ReturnRuleId           INT = NULL,
    @FromStageId            INT,
    @ToStageId              INT,
    @ResetApprovalsOnReturn BIT = 1,
    @RequireComment         BIT = 1,
    @ActorUserId            UNIQUEIDENTIFIER,
    @ResultReturnRuleId     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @ReturnRuleId IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.wf_ReturnRule WHERE ReturnRuleId = @ReturnRuleId)
    BEGIN
        UPDATE dbo.wf_ReturnRule
        SET FromStageId = @FromStageId, ToStageId = @ToStageId,
            ResetApprovalsOnReturn = @ResetApprovalsOnReturn, RequireComment = @RequireComment
        WHERE ReturnRuleId = @ReturnRuleId;
        SET @ResultReturnRuleId = @ReturnRuleId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.wf_ReturnRule (FromStageId, ToStageId, ResetApprovalsOnReturn, RequireComment)
        VALUES (@FromStageId, @ToStageId, @ResetApprovalsOnReturn, @RequireComment);
        SET @ResultReturnRuleId = SCOPE_IDENTITY();
    END

    INSERT INTO dbo.wf_AuditLog (EntityType, EntityId, Action, ActorUserId)
    VALUES ('ReturnRule', CAST(@ResultReturnRuleId AS NVARCHAR(20)), 'Upsert', @ActorUserId);
END
GO
