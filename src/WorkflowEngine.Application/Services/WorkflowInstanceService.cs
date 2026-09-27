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
        var routingError = await routingService.RouteAndAdvanceAsync(
            started.WorkflowInstanceId, started.InitialStageId, null, request.ContextDataJson, startedByUserId);
        if (routingError is not null)
            throw new InvalidOperationException(
                $"Workflow instance {started.WorkflowInstanceId} was created but is Errored: {routingError}");

        return started.WorkflowInstanceId;
    }

    public Task<InstanceStatusResult?> GetInstanceStatusAsync(Guid workflowInstanceId) =>
        runtimeRepository.GetWorkflowInstanceStatusAsync(workflowInstanceId);

    public Task<IReadOnlyList<ApprovalActionEntry>> GetInstanceHistoryAsync(Guid workflowInstanceId) =>
        runtimeRepository.GetWorkflowInstanceHistoryAsync(workflowInstanceId);

    public Task<IReadOnlyList<WorkflowInstance>> FindInstancesAsync(WorkflowInstanceQuery query, Guid currentUserId) =>
        runtimeRepository.GetWorkflowInstancesAsync(
            query.BusinessEntityType, query.BusinessEntityId, query.WorkflowDefinitionCode,
            query.Mine ? currentUserId : null, query.Status, Math.Clamp(query.Top, 1, 1000));

    public async Task ResumeInstanceAsync(Guid workflowInstanceId, ResumeWorkflowInstanceRequest request, Guid actorUserId)
    {
        var resumed = await runtimeRepository.ResumeWorkflowInstanceAsync(
            workflowInstanceId, actorUserId, request.UpdatedContextDataJson);

        if (!resumed.NeedsRouting) return;

        var status = await runtimeRepository.GetWorkflowInstanceStatusAsync(workflowInstanceId)
            ?? throw new InvalidOperationException("Workflow instance not found after resume.");

        var routingError = await routingService.RouteAndAdvanceAsync(
            workflowInstanceId, resumed.CurrentStageId, resumed.ResumeToStageId, status.Instance.ContextDataJson, actorUserId);
        if (routingError is not null)
            throw new InvalidOperationException($"Workflow instance {workflowInstanceId} is Errored: {routingError}");
    }
}
