namespace WorkflowEngine.Application.Abstractions;

// Resolves which stage a workflow instance should move to next by evaluating
// wf_Transition.ConditionExpression (via NCalc) against the instance's
// ContextDataJson. SQL only supplies ordered candidates; all condition
// evaluation happens here so the rules stay testable outside the database.
public interface IWorkflowRoutingService
{
    Task<int> ResolveNextStageAsync(int fromStageId, string? contextDataJson);
}
