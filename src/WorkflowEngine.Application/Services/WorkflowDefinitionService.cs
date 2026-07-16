using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Domain.Entities;
using WorkflowEngine.Infrastructure.Repositories;

namespace WorkflowEngine.Application.Services;

public class WorkflowDefinitionService(IWorkflowMetadataRepository metadataRepository) : IWorkflowDefinitionService
{
    public Task<IReadOnlyList<WorkflowDefinition>> GetDefinitionsAsync() =>
        metadataRepository.GetWorkflowDefinitionsAsync();

    public Task<WorkflowVersionDetail?> GetVersionDetailAsync(int workflowVersionId) =>
        metadataRepository.GetWorkflowVersionDetailAsync(workflowVersionId);

    public Task<int> UpsertDefinitionAsync(UpsertWorkflowDefinitionRequest request, Guid actorUserId) =>
        metadataRepository.UpsertWorkflowDefinitionAsync(request.Code, request.Name, request.Description, request.IsActive, actorUserId);

    public Task<int> CreateVersionAsync(int workflowDefinitionId, Guid actorUserId) =>
        metadataRepository.CreateWorkflowVersionAsync(workflowDefinitionId, actorUserId);

    public Task PublishVersionAsync(int workflowVersionId, Guid actorUserId) =>
        metadataRepository.PublishWorkflowVersionAsync(workflowVersionId, actorUserId);

    public Task<int> UpsertStageAsync(int workflowVersionId, UpsertStageRequest request, Guid actorUserId) =>
        metadataRepository.UpsertStageAsync(workflowVersionId, request.StageKey, request.Name, request.StageOrder,
            request.StageType, request.ParallelGroupId, request.IsInitial, request.IsFinal, actorUserId);

    public Task<int> UpsertTransitionAsync(int workflowVersionId, UpsertTransitionRequest request, Guid actorUserId) =>
        metadataRepository.UpsertTransitionAsync(request.TransitionId, workflowVersionId, request.FromStageId,
            request.ToStageId, request.ConditionExpression, request.Priority, request.IsDefault, actorUserId);

    public Task<int> UpsertParallelGroupAsync(int workflowVersionId, UpsertParallelGroupRequest request, Guid actorUserId) =>
        metadataRepository.UpsertParallelGroupAsync(workflowVersionId, request.Code, request.Name,
            request.JoinType, request.MinRequiredApprovals, actorUserId);

    public Task<int> UpsertApprovalGroupAsync(UpsertApprovalGroupRequest request, Guid actorUserId) =>
        metadataRepository.UpsertApprovalGroupAsync(request.Code, request.Name, request.IsActive, actorUserId);

    public Task<int> UpsertApprovalGroupMemberAsync(int approvalGroupId, UpsertApprovalGroupMemberRequest request, Guid actorUserId) =>
        metadataRepository.UpsertApprovalGroupMemberAsync(approvalGroupId, request.MemberType, request.UserId,
            request.RoleCode, request.IsActive, actorUserId);

    public Task<int> UpsertApprovalRuleAsync(UpsertApprovalRuleRequest request, Guid actorUserId) =>
        metadataRepository.UpsertApprovalRuleAsync(request.ApprovalRuleId, request.StageId, request.ApproverType,
            request.SpecificUserId, request.ApproverRoleCode, request.ApprovalGroupId, request.RequiredCount, actorUserId);

    public Task<int> UpsertReturnRuleAsync(UpsertReturnRuleRequest request, Guid actorUserId) =>
        metadataRepository.UpsertReturnRuleAsync(request.ReturnRuleId, request.FromStageId, request.ToStageId,
            request.ResetApprovalsOnReturn, request.RequireComment, actorUserId);
}
