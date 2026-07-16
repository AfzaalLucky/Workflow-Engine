using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Domain.Entities;
using WorkflowEngine.Infrastructure.Repositories;

namespace WorkflowEngine.Application.Services;

public class ApprovalTaskService(
    IWorkflowRuntimeRepository runtimeRepository,
    IWorkflowRoutingService routingService) : IApprovalTaskService
{
    public Task<IReadOnlyList<ApprovalTask>> GetMyTasksAsync(Guid userId, IReadOnlyList<string> roleCodes) =>
        runtimeRepository.GetMyPendingTasksAsync(userId, roleCodes);

    public Task<TaskDetailResult?> GetTaskDetailAsync(long approvalTaskId) =>
        runtimeRepository.GetTaskDetailAsync(approvalTaskId);

    public async Task<ActOnTaskResult> ActOnTaskAsync(
        long approvalTaskId, Guid actorUserId, IReadOnlyList<string> actorRoleCodes, ActOnTaskRequest request)
    {
        var result = await runtimeRepository.ActOnTaskAsync(
            approvalTaskId, actorUserId, actorRoleCodes, request.Action, request.Comments, request.ReturnToStageId);

        if (!result.NeedsRouting || result.RoutingFromStageId is null)
            return result;

        // The stage's approval rules are now fully satisfied (or, for a
        // parallel group, its join condition just completed) -- resolve and
        // take the outgoing transition.
        var status = await runtimeRepository.GetWorkflowInstanceStatusAsync(result.WorkflowInstanceId)
            ?? throw new InvalidOperationException("Workflow instance not found after acting on task.");

        var nextStageId = await routingService.ResolveNextStageAsync(
            result.RoutingFromStageId.Value, status.Instance.ContextDataJson);

        await runtimeRepository.AdvanceToStageAsync(result.WorkflowInstanceId, nextStageId, actorUserId);

        return result;
    }
}
