namespace WorkflowEngine.Application.Abstractions;

// Resolves which stage a workflow instance should move to next by evaluating
// wf_Transition.ConditionExpression (via NCalc) against the instance's
// ContextDataJson. SQL only supplies ordered candidates; all condition
// evaluation happens here so the rules stay testable outside the database.
public interface IWorkflowRoutingService
{
    Task<int> ResolveNextStageAsync(int fromStageId, string? contextDataJson);

    // Moves an instance on from a satisfied stage: straight to
    // resumeToStageId when set (a ReturnToOrigin return), otherwise via the
    // transitions out of fromStageId. If routing fails the instance is marked
    // Errored (recoverable via resume) and the error message is returned;
    // returns null on success.
    Task<string?> RouteAndAdvanceAsync(
        Guid workflowInstanceId, int fromStageId, int? resumeToStageId, string? contextDataJson, Guid actorUserId);
}
