using WorkflowEngine.Domain.Entities;

namespace WorkflowEngine.Infrastructure.Repositories;

public interface IWorkflowRuntimeRepository
{
    Task<StartInstanceResult> StartWorkflowInstanceAsync(
        string workflowDefinitionCode, string businessEntityType, string businessEntityId,
        string? contextDataJson, Guid startedByUserId);

    Task AdvanceToStageAsync(Guid workflowInstanceId, int toStageId, Guid actorUserId);

    Task<IReadOnlyList<CandidateTransition>> GetCandidateTransitionsAsync(int fromStageId);

    Task<ActOnTaskResult> ActOnTaskAsync(
        long approvalTaskId, Guid actorUserId, IEnumerable<string> actorRoleCodes,
        string action, string? comments, int? returnToStageId);

    Task<ResumeInstanceResult> ResumeWorkflowInstanceAsync(
        Guid workflowInstanceId, Guid actorUserId, string? updatedContextDataJson);

    Task<IReadOnlyList<ApprovalTask>> GetMyPendingTasksAsync(Guid userId, IEnumerable<string> roleCodes);

    Task<TaskDetailResult?> GetTaskDetailAsync(long approvalTaskId);

    Task<InstanceStatusResult?> GetWorkflowInstanceStatusAsync(Guid workflowInstanceId);

    Task<IReadOnlyList<ApprovalActionEntry>> GetWorkflowInstanceHistoryAsync(Guid workflowInstanceId);
}
