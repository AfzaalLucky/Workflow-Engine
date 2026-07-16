using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Domain.Entities;

namespace WorkflowEngine.Application.Services;

public interface IWorkflowInstanceService
{
    Task<Guid> StartInstanceAsync(StartWorkflowInstanceRequest request, Guid startedByUserId);
    Task<InstanceStatusResult?> GetInstanceStatusAsync(Guid workflowInstanceId);
    Task<IReadOnlyList<ApprovalActionEntry>> GetInstanceHistoryAsync(Guid workflowInstanceId);
    Task ResumeInstanceAsync(Guid workflowInstanceId, ResumeWorkflowInstanceRequest request, Guid actorUserId);
}
