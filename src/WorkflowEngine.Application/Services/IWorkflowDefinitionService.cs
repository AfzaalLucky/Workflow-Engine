using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Domain.Entities;

namespace WorkflowEngine.Application.Services;

public interface IWorkflowDefinitionService
{
    Task<IReadOnlyList<WorkflowDefinition>> GetDefinitionsAsync();
    Task<WorkflowVersionDetail?> GetVersionDetailAsync(int workflowVersionId);

    Task<int> UpsertDefinitionAsync(UpsertWorkflowDefinitionRequest request, Guid actorUserId);
    Task<int> CreateVersionAsync(int workflowDefinitionId, Guid actorUserId);
    Task PublishVersionAsync(int workflowVersionId, Guid actorUserId);

    Task<int> UpsertStageAsync(int workflowVersionId, UpsertStageRequest request, Guid actorUserId);
    Task<int> UpsertTransitionAsync(int workflowVersionId, UpsertTransitionRequest request, Guid actorUserId);
    Task<int> UpsertParallelGroupAsync(int workflowVersionId, UpsertParallelGroupRequest request, Guid actorUserId);
    Task<int> UpsertApprovalGroupAsync(UpsertApprovalGroupRequest request, Guid actorUserId);
    Task<int> UpsertApprovalGroupMemberAsync(int approvalGroupId, UpsertApprovalGroupMemberRequest request, Guid actorUserId);
    Task<int> UpsertApprovalRuleAsync(UpsertApprovalRuleRequest request, Guid actorUserId);
    Task<int> UpsertReturnRuleAsync(UpsertReturnRuleRequest request, Guid actorUserId);
}
