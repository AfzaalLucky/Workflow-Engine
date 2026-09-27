using System.Text.Json;
using Microsoft.Extensions.Options;
using WorkflowEngine.Infrastructure.Repositories;

namespace WorkflowEngine.Application.Events;

public interface IWorkflowEventProcessor
{
    // Claims one batch from the outbox and delivers it to every matching
    // handler. Returns the number of events claimed (0 = outbox drained).
    Task<int> ProcessBatchAsync(CancellationToken cancellationToken);
}

public class WorkflowEventProcessor(
    IWorkflowEventRepository eventRepository,
    IEnumerable<IWorkflowEventHandler> handlers,
    IOptions<WorkflowEventOptions> options) : IWorkflowEventProcessor
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<int> ProcessBatchAsync(CancellationToken cancellationToken)
    {
        var settings = options.Value;
        var claimed = await eventRepository.ClaimPendingAsync(settings.BatchSize, settings.LeaseSeconds);

        // Claim returns at most one event per instance, so handling the batch
        // sequentially preserves per-instance ordering.
        foreach (var record in claimed)
        {
            cancellationToken.ThrowIfCancellationRequested();
            string? error = null;
            try
            {
                var message = (JsonSerializer.Deserialize<WorkflowEventMessage>(record.PayloadJson, JsonOptions)
                    ?? throw new InvalidOperationException("Empty event payload."))
                    with { EventId = record.EventId, AttemptCount = record.AttemptCount };

                foreach (var handler in handlers)
                {
                    if (handler.CanHandle(message))
                        await handler.HandleAsync(message, cancellationToken);
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                error = $"{ex.GetType().Name}: {ex.Message}";
            }

            await eventRepository.CompleteAsync(
                record.EventId, error is null, error, settings.MaxAttempts, settings.RetryDelaySeconds);
        }

        return claimed.Count;
    }
}
