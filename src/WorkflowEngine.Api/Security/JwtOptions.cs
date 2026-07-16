namespace WorkflowEngine.Api.Security;

public class JwtOptions
{
    public string Issuer { get; set; } = "";
    public string Audience { get; set; } = "";
    public string SigningKey { get; set; } = "";
    public int ExpiryMinutes { get; set; } = 480;
}
