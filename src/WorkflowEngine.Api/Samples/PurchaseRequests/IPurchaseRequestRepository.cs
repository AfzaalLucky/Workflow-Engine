namespace WorkflowEngine.Api.Samples.PurchaseRequests;

public interface IPurchaseRequestRepository
{
    Task<int> CreateAsync(Guid requestedByUserId, string title, string? description, decimal amount, string department);
    Task SetWorkflowInstanceAsync(int purchaseRequestId, Guid workflowInstanceId);
    Task<PurchaseRequest?> GetAsync(int purchaseRequestId);
    Task<IReadOnlyList<PurchaseRequest>> GetMineAsync(Guid requestedByUserId);
}
