using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Domain.Entities;

namespace WorkflowEngine.Application.Services;

public interface IApprovalTaskService
{
    Task<IReadOnlyList<ApprovalTask>> GetMyTasksAsync(Guid userId, IReadOnlyList<string> roleCodes);
    Task<TaskDetailResult?> GetTaskDetailAsync(long approvalTaskId);

    Task<ActOnTaskResult> ActOnTaskAsync(
        long approvalTaskId, Guid actorUserId, IReadOnlyList<string> actorRoleCodes, ActOnTaskRequest request);
}
