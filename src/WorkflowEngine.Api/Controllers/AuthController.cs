using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WorkflowEngine.Api.Security;
using WorkflowEngine.Infrastructure.Repositories;

namespace WorkflowEngine.Api.Controllers;

[ApiController]
[Route("api/auth")]
[AllowAnonymous]
public class AuthController(JwtTokenService tokenService, IWorkflowMetadataRepository metadataRepository) : ControllerBase
{
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var user = DemoUserStore.FindByCredentials(request.Username, request.Password);
        if (user is null)
            return Unauthorized(new { message = "Invalid username or password." });

        var (token, expiresAt) = tokenService.IssueToken(user);

        // Keeps wf_UserRef fresh so the audit trail can show a display name
        // instead of a bare GUID for this actor.
        await metadataRepository.UpsertUserRefAsync(user.UserId, user.DisplayName, email: null);

        return Ok(new LoginResponse(token, expiresAt, user.UserId, user.DisplayName, user.Roles));
    }
}

public record LoginRequest(string Username, string Password);
public record LoginResponse(string Token, DateTime ExpiresAt, Guid UserId, string DisplayName, string[] Roles);
