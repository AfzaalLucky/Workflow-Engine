using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Domain.Entities;
using WorkflowEngine.Infrastructure.Repositories;

namespace WorkflowEngine.Application.Services;

public class WorkflowInstanceService(
    IWorkflowRuntimeRepository runtimeRepository,
    IWorkflowRoutingService routingService) : IWorkflowInstanceService
{
    public async Task<Guid> StartInstanceAsync(StartWorkflowInstanceRequest request, Guid startedByUserId)
    {
        var started = await runtimeRepository.StartWorkflowInstanceAsync(
            request.WorkflowDefinitionCode, request.BusinessEntityType, request.BusinessEntityId,
            request.ContextDataJson, startedByUserId);

        // The initial (Start) stage never carries approval rules -- immediately
        // resolve and take its outgoing transition so the instance lands on
        // the first real approval stage.
        var nextStageId = await routingService.ResolveNextStageAsync(started.InitialStageId, request.ContextDataJson);
        await runtimeRepository.AdvanceToStageAsync(started.WorkflowInstanceId, nextStageId, startedByUserId);

        return started.WorkflowInstanceId;
    }

    public Task<InstanceStatusResult?> GetInstanceStatusAsync(Guid workflowInstanceId) =>
        runtimeRepository.GetWorkflowInstanceStatusAsync(workflowInstanceId);

    public Task<IReadOnlyList<ApprovalActionEntry>> GetInstanceHistoryAsync(Guid workflowInstanceId) =>
        runtimeRepository.GetWorkflowInstanceHistoryAsync(workflowInstanceId);

    public async Task ResumeInstanceAsync(Guid workflowInstanceId, ResumeWorkflowInstanceRequest request, Guid actorUserId)
    {
        var resumed = await runtimeRepository.ResumeWorkflowInstanceAsync(
            workflowInstanceId, actorUserId, request.UpdatedContextDataJson);

        if (!resumed.NeedsRouting) return;

        var status = await runtimeRepository.GetWorkflowInstanceStatusAsync(workflowInstanceId)
            ?? throw new InvalidOperationException("Workflow instance not found after resume.");

        var nextStageId = await routingService.ResolveNextStageAsync(resumed.CurrentStageId, status.Instance.ContextDataJson);
        await runtimeRepository.AdvanceToStageAsync(workflowInstanceId, nextStageId, actorUserId);
    }
}
