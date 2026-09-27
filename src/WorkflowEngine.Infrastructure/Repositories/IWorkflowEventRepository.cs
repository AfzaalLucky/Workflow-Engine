using WorkflowEngine.Domain.Entities;

namespace WorkflowEngine.Infrastructure.Repositories;

public interface IWorkflowEventRepository
{
    Task<IReadOnlyList<WorkflowEventRecord>> ClaimPendingAsync(int batchSize, int leaseSeconds);

    Task CompleteAsync(long eventId, bool succeeded, string? error, int maxAttempts, int retryDelaySeconds);
}
