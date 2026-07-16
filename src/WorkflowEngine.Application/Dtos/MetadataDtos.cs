namespace WorkflowEngine.Application.Dtos;

public record UpsertWorkflowDefinitionRequest(string Code, string Name, string? Description, bool IsActive = true);

public record UpsertStageRequest(
    string StageKey, string Name, int StageOrder, string StageType,
    int? ParallelGroupId, bool IsInitial = false, bool IsFinal = false);

public record UpsertTransitionRequest(
    int? TransitionId, int FromStageId, int ToStageId,
    string? ConditionExpression, int Priority = 100, bool IsDefault = false);

public record UpsertParallelGroupRequest(
    string Code, string Name, string JoinType = "All", int? MinRequiredApprovals = null);

public record UpsertApprovalGroupRequest(string Code, string Name, bool IsActive = true);

public record UpsertApprovalGroupMemberRequest(
    string MemberType, Guid? UserId, string? RoleCode, bool IsActive = true);

public record UpsertApprovalRuleRequest(
    int? ApprovalRuleId, int StageId, string ApproverType,
    Guid? SpecificUserId, string? ApproverRoleCode, int? ApprovalGroupId, int RequiredCount = 1);

public record UpsertReturnRuleRequest(
    int? ReturnRuleId, int FromStageId, int ToStageId,
    bool ResetApprovalsOnReturn = true, bool RequireComment = true);
