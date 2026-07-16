-- Returns ordered candidates for .NET to evaluate via NCalc: conditional
-- transitions first (by Priority), the default transition last as fallback.
CREATE OR ALTER PROCEDURE dbo.wf_GetCandidateTransitions
    @FromStageId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TransitionId, FromStageId, ToStageId, ConditionExpression, Priority, IsDefault
    FROM dbo.wf_Transition
    WHERE FromStageId = @FromStageId
    ORDER BY IsDefault ASC, Priority ASC;
END
GO
