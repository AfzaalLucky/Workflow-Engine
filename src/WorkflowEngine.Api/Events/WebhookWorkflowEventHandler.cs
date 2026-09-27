using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using WorkflowEngine.Application.Events;

namespace WorkflowEngine.Api.Events;

// Forwards events to the HTTP endpoints configured under
// WorkflowEvents:Webhooks, so a host application in any language or
// process (a Next.js site, another .NET service, n8n/Zapier...) can react
// to workflow progress without referencing this codebase.
public class WebhookWorkflowEventHandler(
    IHttpClientFactory httpClientFactory,
    IOptions<WorkflowEventOptions> options) : IWorkflowEventHandler
{
    public const string HttpClientName = "WorkflowWebhooks";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public bool CanHandle(WorkflowEventMessage message) =>
        options.Value.Webhooks.Any(w => w.Matches(message));

    public async Task HandleAsync(WorkflowEventMessage message, CancellationToken cancellationToken)
    {
        var body = JsonSerializer.Serialize(message, JsonOptions);
        var client = httpClientFactory.CreateClient(HttpClientName);

        foreach (var webhook in options.Value.Webhooks.Where(w => w.Matches(message)))
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, webhook.Url)
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json")
            };
            request.Headers.Add("X-Workflow-Event", message.EventType);
            // Stable across retries -- receivers dedupe on this.
            request.Headers.Add("X-Workflow-Event-Id", message.EventId.ToString());
            if (!string.IsNullOrEmpty(webhook.Secret))
                request.Headers.Add("X-Workflow-Signature", "sha256=" + Sign(body, webhook.Secret));

            using var response = await client.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                throw new HttpRequestException(
                    $"Webhook {webhook.Url} returned {(int)response.StatusCode} {response.ReasonPhrase}.");
        }
    }

    private static string Sign(string body, string secret) =>
        Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes(body))).ToLowerInvariant();
}
