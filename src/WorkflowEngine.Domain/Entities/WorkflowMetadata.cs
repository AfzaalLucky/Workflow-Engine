namespace WorkflowEngine.Domain.Entities;

public class WorkflowDefinition
{
    public int WorkflowDefinitionId { get; set; }
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public int? PublishedVersionId { get; set; }
    public int? PublishedVersionNumber { get; set; }
}

public class WorkflowVersion
{
    public int WorkflowVersionId { get; set; }
    public int WorkflowDefinitionId { get; set; }
    public int VersionNumber { get; set; }
    public string Status { get; set; } = "";
    public DateTime? PublishedAt { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class Stage
{
    public int StageId { get; set; }
    public int WorkflowVersionId { get; set; }
    public string StageKey { get; set; } = "";
    public string Name { get; set; } = "";
    public int StageOrder { get; set; }
    public string StageType { get; set; } = "";
    public int? ParallelGroupId { get; set; }
    public bool IsInitial { get; set; }
    public bool IsFinal { get; set; }
}

public class ParallelGroup
{
    public int ParallelGroupId { get; set; }
    public int WorkflowVersionId { get; set; }
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string JoinType { get; set; } = "";
    public int? MinRequiredApprovals { get; set; }
}

public class Transition
{
    public int TransitionId { get; set; }
    public int WorkflowVersionId { get; set; }
    public int FromStageId { get; set; }
    public int ToStageId { get; set; }
    public string? ConditionExpression { get; set; }
    public int Priority { get; set; }
    public bool IsDefault { get; set; }
}

public class ApprovalRule
{
    public int ApprovalRuleId { get; set; }
    public int StageId { get; set; }
    public string ApproverType { get; set; } = "";
    public Guid? SpecificUserId { get; set; }
    public string? ApproverRoleCode { get; set; }
    public int? ApprovalGroupId { get; set; }
    public int RequiredCount { get; set; }
}

public class ApprovalGroup
{
    public int ApprovalGroupId { get; set; }
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public bool IsActive { get; set; }
}

public class ApprovalGroupMember
{
    public int ApprovalGroupMemberId { get; set; }
    public int ApprovalGroupId { get; set; }
    public string MemberType { get; set; } = "";
    public Guid? UserId { get; set; }
    public string? RoleCode { get; set; }
    public bool IsActive { get; set; }
}

public class ReturnRule
{
    public int ReturnRuleId { get; set; }
    public int FromStageId { get; set; }
    public int ToStageId { get; set; }
    public string? ToStageName { get; set; }
    public bool ResetApprovalsOnReturn { get; set; }
    public bool RequireComment { get; set; }
}

public class WorkflowVersionDetail
{
    public WorkflowVersion Version { get; set; } = null!;
    public IReadOnlyList<Stage> Stages { get; set; } = [];
    public IReadOnlyList<Transition> Transitions { get; set; } = [];
    public IReadOnlyList<ParallelGroup> ParallelGroups { get; set; } = [];
    public IReadOnlyList<ApprovalRule> ApprovalRules { get; set; } = [];
    public IReadOnlyList<ReturnRule> ReturnRules { get; set; } = [];
    public IReadOnlyList<ApprovalGroup> ApprovalGroups { get; set; } = [];
    public IReadOnlyList<ApprovalGroupMember> ApprovalGroupMembers { get; set; } = [];
}
