namespace WorkflowEngine.Api.Samples.LeasingCommissions;

public interface ILeasingCommissionRepository
{
    Task<int> CreateAsync(Guid requestedByUserId, string lesseeName, decimal commissionAmount, string branch, string? notes);
    Task SetWorkflowInstanceAsync(int leasingCommissionId, Guid workflowInstanceId);
    Task<LeasingCommission?> GetAsync(int leasingCommissionId);
    Task<IReadOnlyList<LeasingCommission>> GetMineAsync(Guid requestedByUserId);
}
