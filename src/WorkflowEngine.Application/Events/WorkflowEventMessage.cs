namespace WorkflowEngine.Application.Events;

// Deserialized wf_WorkflowEvent payload (built by dbo.wf_EnqueueEvent). A
// self-contained snapshot: handlers and webhook receivers never need to
// query wf_* tables to act on it. ExternalStatusCode is the host app's own
// status for the stage (wf_Stage.ExternalStatusCode), e.g. "20".
public record WorkflowEventMessage
{
    public long EventId { get; init; }
    public int AttemptCount { get; init; }
    public string EventType { get; init; } = "";
    public Guid WorkflowInstanceId { get; init; }
    public string WorkflowDefinitionCode { get; init; } = "";
    public int WorkflowVersionNumber { get; init; }
    public string BusinessEntityType { get; init; } = "";
    public string BusinessEntityId { get; init; } = "";
    public string InstanceStatus { get; init; } = "";
    public int? StageId { get; init; }
    public string? StageKey { get; init; }
    public string? StageName { get; init; }
    public string? StageType { get; init; }
    public string? ExternalStatusCode { get; init; }
    public Guid ActorUserId { get; init; }
    public string? Comments { get; init; }
    public DateTime OccurredAt { get; init; }
}
