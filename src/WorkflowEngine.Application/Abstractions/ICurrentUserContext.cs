namespace WorkflowEngine.Application.Abstractions;

// Implemented in the Api layer against the current request's ClaimsPrincipal.
// The engine never stores identity/roles itself -- this is the seam between
// "whoever the JWT says you are" and the engine's authorization checks.
public interface ICurrentUserContext
{
    Guid UserId { get; }
    string DisplayName { get; }
    IReadOnlyList<string> Roles { get; }
}
