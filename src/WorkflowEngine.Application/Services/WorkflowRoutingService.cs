using System.Text.Json;
using NCalc;
using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Infrastructure.Repositories;

namespace WorkflowEngine.Application.Services;

public class WorkflowRoutingService(IWorkflowRuntimeRepository runtimeRepository) : IWorkflowRoutingService
{
    public async Task<int> ResolveNextStageAsync(int fromStageId, string? contextDataJson)
    {
        var candidates = await runtimeRepository.GetCandidateTransitionsAsync(fromStageId);
        if (candidates.Count == 0)
            throw new InvalidOperationException($"No outgoing transitions configured for stage {fromStageId}.");

        var context = ParseContext(contextDataJson);

        // Candidates arrive ordered conditional-first (by Priority), default last.
        foreach (var candidate in candidates)
        {
            if (string.IsNullOrWhiteSpace(candidate.ConditionExpression))
            {
                if (candidate.IsDefault)
                    return candidate.ToStageId;
                continue;
            }

            var expression = new Expression(candidate.ConditionExpression);
            foreach (var (key, value) in context)
                expression.Parameters[key] = value;

            if (expression.Evaluate() is true)
                return candidate.ToStageId;
        }

        throw new InvalidOperationException(
            $"No transition condition matched and no default transition is configured from stage {fromStageId}.");
    }

    private static Dictionary<string, object> ParseContext(string? contextDataJson)
    {
        var result = new Dictionary<string, object>();
        if (string.IsNullOrWhiteSpace(contextDataJson)) return result;

        using var document = JsonDocument.Parse(contextDataJson);
        foreach (var property in document.RootElement.EnumerateObject())
        {
            result[property.Name] = property.Value.ValueKind switch
            {
                JsonValueKind.Number => property.Value.GetDouble(),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.String => property.Value.GetString() ?? "",
                _ => property.Value.ToString(),
            };
        }
        return result;
    }
}
