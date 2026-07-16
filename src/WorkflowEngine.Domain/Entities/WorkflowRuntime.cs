namespace WorkflowEngine.Domain.Entities;

public class WorkflowInstance
{
    public Guid WorkflowInstanceId { get; set; }
    public int WorkflowVersionId { get; set; }
    public string BusinessEntityType { get; set; } = "";
    public string BusinessEntityId { get; set; } = "";
    public int? CurrentStageId { get; set; }
    public string? CurrentStageKey { get; set; }
    public string? CurrentStageName { get; set; }
    public string Status { get; set; } = "";
    public string? ContextDataJson { get; set; }
    public Guid StartedByUserId { get; set; }
    public DateTime StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string? WorkflowDefinitionCode { get; set; }
    public string? WorkflowDefinitionName { get; set; }
    public int VersionNumber { get; set; }
}

public class ApprovalTask
{
    public long ApprovalTaskId { get; set; }
    public long InstanceStageId { get; set; }
    public Guid WorkflowInstanceId { get; set; }
    public int ApprovalRuleId { get; set; }
    public Guid? AssignedToUserId { get; set; }
    public string? AssignedToRoleCode { get; set; }
    public int? AssignedToGroupId { get; set; }
    public string Status { get; set; } = "";
    public Guid? CompletedByUserId { get; set; }
    public string? Comments { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? CompletedAt { get; set; }

    public string? StageKey { get; set; }
    public string? StageName { get; set; }
    public string? StageType { get; set; }
    public string? BusinessEntityType { get; set; }
    public string? BusinessEntityId { get; set; }
    public string? ContextDataJson { get; set; }
    public string? InstanceStatus { get; set; }
    public string? WorkflowDefinitionCode { get; set; }
    public string? WorkflowDefinitionName { get; set; }
}

public class ApprovalActionEntry
{
    public long ApprovalActionId { get; set; }
    public string ActionType { get; set; } = "";
    public Guid ActorUserId { get; set; }
    public string? ActorDisplayName { get; set; }
    public DateTime ActionAt { get; set; }
    public string? Comments { get; set; }
    public string? OldStatus { get; set; }
    public string? NewStatus { get; set; }
    public string? OldStageName { get; set; }
    public string? NewStageName { get; set; }
}

public class PendingTaskSummary
{
    public long ApprovalTaskId { get; set; }
    public string Status { get; set; } = "";
    public Guid? AssignedToUserId { get; set; }
    public string? AssignedToRoleCode { get; set; }
    public int? AssignedToGroupId { get; set; }
    public string StageName { get; set; } = "";
}

public class ReturnOption
{
    public int FromStageId { get; set; }
    public int ToStageId { get; set; }
    public string ToStageName { get; set; } = "";
    public bool RequireComment { get; set; }
}

public class TaskDetailResult
{
    public ApprovalTask Task { get; set; } = null!;
    public IReadOnlyList<ReturnOption> ReturnOptions { get; set; } = [];
}

public class InstanceStatusResult
{
    public WorkflowInstance Instance { get; set; } = null!;
    public IReadOnlyList<PendingTaskSummary> PendingTasks { get; set; } = [];
}

public class CandidateTransition
{
    public int TransitionId { get; set; }
    public int FromStageId { get; set; }
    public int ToStageId { get; set; }
    public string? ConditionExpression { get; set; }
    public int Priority { get; set; }
    public bool IsDefault { get; set; }
}

public class ActOnTaskResult
{
    public Guid WorkflowInstanceId { get; set; }
    public bool NeedsRouting { get; set; }
    public int? RoutingFromStageId { get; set; }
}

public class ResumeInstanceResult
{
    public int CurrentStageId { get; set; }
    public bool NeedsRouting { get; set; }
}

public class StartInstanceResult
{
    public Guid WorkflowInstanceId { get; set; }
    public int InitialStageId { get; set; }
}
