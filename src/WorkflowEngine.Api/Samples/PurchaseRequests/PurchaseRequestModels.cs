namespace WorkflowEngine.Api.Samples.PurchaseRequests;

// Ordinary application model, not part of the generic engine -- lives in
// the API project's own sample folder rather than WorkflowEngine.Domain to
// keep the reusable engine core free of any one business process's shape.
public class PurchaseRequest
{
    public int PurchaseRequestId { get; set; }
    public Guid? WorkflowInstanceId { get; set; }
    public Guid RequestedByUserId { get; set; }
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public decimal Amount { get; set; }
    public string Department { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public string? WorkflowStatus { get; set; }
    public string? CurrentStageName { get; set; }
}

public record CreatePurchaseRequestRequest(string Title, string? Description, decimal Amount, string Department);
