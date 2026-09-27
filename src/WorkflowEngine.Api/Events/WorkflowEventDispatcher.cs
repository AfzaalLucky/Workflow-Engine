using Microsoft.Extensions.Options;
using WorkflowEngine.Application.Events;

namespace WorkflowEngine.Api.Events;

// Drains the wf_WorkflowEvent outbox. Safe to run in several API instances
// at once: claims use READPAST row locks, so each event goes to one poller.
public class WorkflowEventDispatcher(
    IServiceScopeFactory scopeFactory,
    IOptions<WorkflowEventOptions> options,
    ILogger<WorkflowEventDispatcher> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.Enabled)
        {
            logger.LogInformation("Workflow event dispatcher is disabled (WorkflowEvents:Enabled=false).");
            return;
        }

        var pollInterval = TimeSpan.FromSeconds(Math.Max(1, options.Value.PollIntervalSeconds));

        while (!stoppingToken.IsCancellationRequested)
        {
            int claimed = 0;
            try
            {
                using var scope = scopeFactory.CreateScope();
                var processor = scope.ServiceProvider.GetRequiredService<IWorkflowEventProcessor>();
                claimed = await processor.ProcessBatchAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Workflow event dispatch cycle failed; retrying after the poll interval.");
            }

            // A full batch means there is probably more waiting -- go again now.
            if (claimed < options.Value.BatchSize)
                await Task.Delay(pollInterval, stoppingToken).ContinueWith(_ => { }, CancellationToken.None);
        }
    }
}
