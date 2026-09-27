using System.Data;
using Dapper;
using WorkflowEngine.Domain.Entities;
using WorkflowEngine.Infrastructure.Data;

namespace WorkflowEngine.Infrastructure.Repositories;

public class WorkflowEventRepository(ISqlConnectionFactory connectionFactory) : IWorkflowEventRepository
{
    public async Task<IReadOnlyList<WorkflowEventRecord>> ClaimPendingAsync(int batchSize, int leaseSeconds)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var result = await connection.QueryAsync<WorkflowEventRecord>(
            "dbo.wf_ClaimWorkflowEvents", new { BatchSize = batchSize, LeaseSeconds = leaseSeconds },
            commandType: CommandType.StoredProcedure);
        return result.ToList();
    }

    public async Task CompleteAsync(long eventId, bool succeeded, string? error, int maxAttempts, int retryDelaySeconds)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        await connection.ExecuteAsync("dbo.wf_CompleteWorkflowEvent", new
        {
            EventId = eventId,
            Succeeded = succeeded,
            Error = error is { Length: > 2000 } ? error[..2000] : error,
            MaxAttempts = maxAttempts,
            RetryDelaySeconds = retryDelaySeconds
        }, commandType: CommandType.StoredProcedure);
    }
}
