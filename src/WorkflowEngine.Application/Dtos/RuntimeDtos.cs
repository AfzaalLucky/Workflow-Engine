namespace WorkflowEngine.Application.Dtos;

public record StartWorkflowInstanceRequest(
    string WorkflowDefinitionCode,
    string BusinessEntityType,
    string BusinessEntityId,
    string? ContextDataJson);

public record ActOnTaskRequest(
    string Action, // Approve | Reject | Return
    string? Comments,
    int? ReturnToStageId);

public record ResumeWorkflowInstanceRequest(string? UpdatedContextDataJson);
