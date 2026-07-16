using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace WorkflowEngine.Api.Security;

public class JwtTokenService(IOptions<JwtOptions> options)
{
    private readonly JwtOptions _options = options.Value;

    public (string Token, DateTime ExpiresAt) IssueToken(DemoUser user)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
            new("displayName", user.DisplayName),
        };
        claims.AddRange(user.Roles.Select(role => new Claim(ClaimTypes.Role, role)));

        var expiresAt = DateTime.UtcNow.AddMinutes(_options.ExpiryMinutes);
        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey));
        var credentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            expires: expiresAt,
            signingCredentials: credentials);

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }
}
