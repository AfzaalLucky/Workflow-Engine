using System.Data;
using Dapper;
using WorkflowEngine.Infrastructure.Data;

namespace WorkflowEngine.Api.Samples.LeasingCommissions;

public class LeasingCommissionRepository(ISqlConnectionFactory connectionFactory) : ILeasingCommissionRepository
{
    public async Task<int> CreateAsync(Guid requestedByUserId, string lesseeName, decimal commissionAmount, string branch, string? notes)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("RequestedByUserId", requestedByUserId);
        parameters.Add("LesseeName", lesseeName);
        parameters.Add("CommissionAmount", commissionAmount);
        parameters.Add("Branch", branch);
        parameters.Add("Notes", notes);
        parameters.Add("LeasingCommissionId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.lc_CreateLeasingCommission", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("LeasingCommissionId");
    }

    public async Task SetWorkflowInstanceAsync(int leasingCommissionId, Guid workflowInstanceId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        await connection.ExecuteAsync("dbo.lc_SetWorkflowInstance",
            new { LeasingCommissionId = leasingCommissionId, WorkflowInstanceId = workflowInstanceId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<LeasingCommission?> GetAsync(int leasingCommissionId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        return await connection.QuerySingleOrDefaultAsync<LeasingCommission>(
            "dbo.lc_GetLeasingCommission", new { LeasingCommissionId = leasingCommissionId }, commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<LeasingCommission>> GetMineAsync(Guid requestedByUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var result = await connection.QueryAsync<LeasingCommission>(
            "dbo.lc_GetMyLeasingCommissions", new { RequestedByUserId = requestedByUserId }, commandType: CommandType.StoredProcedure);
        return result.ToList();
    }
}
