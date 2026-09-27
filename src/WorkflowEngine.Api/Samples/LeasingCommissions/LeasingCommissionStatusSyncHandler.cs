using WorkflowEngine.Application.Events;

namespace WorkflowEngine.Api.Samples.LeasingCommissions;

// How a host application keeps its own status column in step with the
// engine: the stage metadata carries the business status ID
// (wf_Stage.ExternalStatusCode), and each StageEntered / InstanceReturned /
// InstanceApproved event writes it back. Idempotent, as required -- replaying
// an event just rewrites the same value.
public class LeasingCommissionStatusSyncHandler(ILeasingCommissionRepository leasingCommissions) : IWorkflowEventHandler
{
    public bool CanHandle(WorkflowEventMessage message) =>
        message.BusinessEntityType == "LeasingCommission" && message.ExternalStatusCode is not null;

    public Task HandleAsync(WorkflowEventMessage message, CancellationToken cancellationToken) =>
        int.TryParse(message.BusinessEntityId, out var leasingCommissionId)
            ? leasingCommissions.SetStatusCodeAsync(leasingCommissionId, message.ExternalStatusCode!)
            : Task.CompletedTask;
}
