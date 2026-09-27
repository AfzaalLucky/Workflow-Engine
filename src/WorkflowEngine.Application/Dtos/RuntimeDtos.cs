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

public record WorkflowInstanceQuery(
    string? BusinessEntityType = null,
    string? BusinessEntityId = null,
    string? WorkflowDefinitionCode = null,
    string? Status = null,
    bool Mine = false,
    int Top = 200);
