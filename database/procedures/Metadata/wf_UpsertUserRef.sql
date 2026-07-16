-- Upserts the thin identity cache used for display purposes (e.g. showing
-- an actor's name in the audit timeline). Called on login; never a source
-- of truth for identity or roles -- those come from the JWT.
CREATE OR ALTER PROCEDURE dbo.wf_UpsertUserRef
    @UserId      UNIQUEIDENTIFIER,
    @DisplayName NVARCHAR(200),
    @Email       NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.wf_UserRef WHERE UserId = @UserId)
        UPDATE dbo.wf_UserRef SET DisplayName = @DisplayName, Email = @Email, UpdatedAt = SYSUTCDATETIME()
        WHERE UserId = @UserId;
    ELSE
        INSERT INTO dbo.wf_UserRef (UserId, DisplayName, Email) VALUES (@UserId, @DisplayName, @Email);
END
GO
