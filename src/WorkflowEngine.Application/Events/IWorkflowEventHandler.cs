namespace WorkflowEngine.Application.Events;

// The integration seam for host applications: implement this to react to
// workflow progress (sync a business table's status column, send an email,
// publish to a queue...) and register it with AddWorkflowEventHandler<T>().
//
// Delivery is at-least-once and in order per workflow instance, so
// HandleAsync must be idempotent. Throwing marks the event for retry with
// backoff; later events for the same instance wait until it succeeds or is
// dead-lettered.
public interface IWorkflowEventHandler
{
    bool CanHandle(WorkflowEventMessage message);

    Task HandleAsync(WorkflowEventMessage message, CancellationToken cancellationToken);
}
