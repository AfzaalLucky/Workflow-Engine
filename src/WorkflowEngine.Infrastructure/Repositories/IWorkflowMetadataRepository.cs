using WorkflowEngine.Domain.Entities;

namespace WorkflowEngine.Infrastructure.Repositories;

public interface IWorkflowMetadataRepository
{
    Task<IReadOnlyList<WorkflowDefinition>> GetWorkflowDefinitionsAsync();
    Task<WorkflowVersionDetail?> GetWorkflowVersionDetailAsync(int workflowVersionId);

    Task<int> UpsertWorkflowDefinitionAsync(string code, string name, string? description, bool isActive, Guid actorUserId);
    Task<int> CreateWorkflowVersionAsync(int workflowDefinitionId, Guid actorUserId);
    Task PublishWorkflowVersionAsync(int workflowVersionId, Guid actorUserId);

    Task<int> UpsertStageAsync(int workflowVersionId, string stageKey, string name, int stageOrder,
        string stageType, int? parallelGroupId, bool isInitial, bool isFinal, Guid actorUserId);

    Task<int> UpsertTransitionAsync(int? transitionId, int workflowVersionId, int fromStageId, int toStageId,
        string? conditionExpression, int priority, bool isDefault, Guid actorUserId);

    Task<int> UpsertParallelGroupAsync(int workflowVersionId, string code, string name, string joinType,
        int? minRequiredApprovals, Guid actorUserId);

    Task<int> UpsertApprovalGroupAsync(string code, string name, bool isActive, Guid actorUserId);

    Task<int> UpsertApprovalGroupMemberAsync(int approvalGroupId, string memberType, Guid? userId,
        string? roleCode, bool isActive, Guid actorUserId);

    Task<int> UpsertApprovalRuleAsync(int? approvalRuleId, int stageId, string approverType, Guid? specificUserId,
        string? approverRoleCode, int? approvalGroupId, int requiredCount, Guid actorUserId);

    Task<int> UpsertReturnRuleAsync(int? returnRuleId, int fromStageId, int toStageId,
        bool resetApprovalsOnReturn, bool requireComment, Guid actorUserId);

    Task UpsertUserRefAsync(Guid userId, string displayName, string? email);
}
