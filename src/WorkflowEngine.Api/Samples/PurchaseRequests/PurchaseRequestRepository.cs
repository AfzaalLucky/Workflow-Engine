using System.Data;
using Dapper;
using WorkflowEngine.Infrastructure.Data;

namespace WorkflowEngine.Api.Samples.PurchaseRequests;

// Reuses the engine's ISqlConnectionFactory (same database) but calls its
// own pr_* procedures -- the business module owns its own schema and data
// access, entirely separate from the wf_* engine repositories.
public class PurchaseRequestRepository(ISqlConnectionFactory connectionFactory) : IPurchaseRequestRepository
{
    public async Task<int> CreateAsync(Guid requestedByUserId, string title, string? description, decimal amount, string department)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("RequestedByUserId", requestedByUserId);
        parameters.Add("Title", title);
        parameters.Add("Description", description);
        parameters.Add("Amount", amount);
        parameters.Add("Department", department);
        parameters.Add("PurchaseRequestId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.pr_CreatePurchaseRequest", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("PurchaseRequestId");
    }

    public async Task SetWorkflowInstanceAsync(int purchaseRequestId, Guid workflowInstanceId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        await connection.ExecuteAsync("dbo.pr_SetWorkflowInstance",
            new { PurchaseRequestId = purchaseRequestId, WorkflowInstanceId = workflowInstanceId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<PurchaseRequest?> GetAsync(int purchaseRequestId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        return await connection.QuerySingleOrDefaultAsync<PurchaseRequest>(
            "dbo.pr_GetPurchaseRequest", new { PurchaseRequestId = purchaseRequestId }, commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<PurchaseRequest>> GetMineAsync(Guid requestedByUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var result = await connection.QueryAsync<PurchaseRequest>(
            "dbo.pr_GetMyPurchaseRequests", new { RequestedByUserId = requestedByUserId }, commandType: CommandType.StoredProcedure);
        return result.ToList();
    }
}
