namespace WorkflowEngine.Api.Samples.LeasingCommissions;

// Ordinary application model, not part of the generic engine -- see
// LeasingFlow.md for the source business rules and
// database/seed/seed_leasing_commission_workflow.sql for how they map
// onto wf_* metadata.
public class LeasingCommission
{
    public int LeasingCommissionId { get; set; }
    public Guid? WorkflowInstanceId { get; set; }
    public Guid RequestedByUserId { get; set; }
    public string LesseeName { get; set; } = "";
    public decimal CommissionAmount { get; set; }
    public string Branch { get; set; } = "";
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? WorkflowStatus { get; set; }
    public string? CurrentStageName { get; set; }
}

public record CreateLeasingCommissionRequest(string LesseeName, decimal CommissionAmount, string Branch, string? Notes);
