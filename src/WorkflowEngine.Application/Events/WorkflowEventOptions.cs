namespace WorkflowEngine.Application.Events;

// Bound from the "WorkflowEvents" configuration section.
public class WorkflowEventOptions
{
    public bool Enabled { get; set; } = true;
    public int PollIntervalSeconds { get; set; } = 5;
    public int BatchSize { get; set; } = 50;
    public int LeaseSeconds { get; set; } = 60;
    public int MaxAttempts { get; set; } = 10;
    public int RetryDelaySeconds { get; set; } = 15;

    // Outbound HTTP callbacks, for host apps that live in another process or
    // language. Each receives a JSON POST of the event, signed with
    // X-Workflow-Signature: sha256=<hex HMAC of the body using Secret>.
    public List<WebhookSubscription> Webhooks { get; set; } = [];
}

public class WebhookSubscription
{
    public string Url { get; set; } = "";
    public string? Secret { get; set; }

    // Empty = all. Otherwise only events whose definition code / business
    // entity type / event type is listed.
    public List<string> WorkflowDefinitionCodes { get; set; } = [];
    public List<string> BusinessEntityTypes { get; set; } = [];
    public List<string> EventTypes { get; set; } = [];

    public bool Matches(WorkflowEventMessage message) =>
        (WorkflowDefinitionCodes.Count == 0 || WorkflowDefinitionCodes.Contains(message.WorkflowDefinitionCode, StringComparer.OrdinalIgnoreCase)) &&
        (BusinessEntityTypes.Count == 0 || BusinessEntityTypes.Contains(message.BusinessEntityType, StringComparer.OrdinalIgnoreCase)) &&
        (EventTypes.Count == 0 || EventTypes.Contains(message.EventType, StringComparer.OrdinalIgnoreCase));
}
