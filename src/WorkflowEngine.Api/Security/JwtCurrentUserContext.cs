using System.Security.Claims;
using WorkflowEngine.Application.Abstractions;

namespace WorkflowEngine.Api.Security;

// Reads the authenticated caller's identity and role claims straight from
// the validated JWT. This is the seam the engine's authorization checks
// are actually validated against server-side (in wf_ActOnTask) -- the API
// layer never has to be trusted on its own.
public class JwtCurrentUserContext(IHttpContextAccessor httpContextAccessor) : ICurrentUserContext
{
    private ClaimsPrincipal User =>
        httpContextAccessor.HttpContext?.User
            ?? throw new InvalidOperationException("No HTTP context available to resolve the current user.");

    public Guid UserId
    {
        get
        {
            var subject = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return Guid.TryParse(subject, out var userId)
                ? userId
                : throw new InvalidOperationException("JWT is missing a valid subject claim.");
        }
    }

    public string DisplayName => User.FindFirstValue("displayName") ?? "Unknown User";

    public IReadOnlyList<string> Roles => User.FindAll(ClaimTypes.Role).Select(c => c.Value).ToList();
}
