using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Application.Services;

namespace WorkflowEngine.Api.Controllers;

// Admin/designer endpoints: full metadata CRUD for stages, transitions,
// approval rules, parallel groups, approval groups, and return rules.
// A new business process is added purely through these endpoints -- no
// code or schema changes required.
[ApiController]
[Authorize(Roles = "WorkflowAdmin")]
[Route("api/admin")]
public class WorkflowAdminController(
    IWorkflowDefinitionService definitionService,
    ICurrentUserContext currentUser) : ControllerBase
{
    [HttpGet("workflow-definitions")]
    public async Task<IActionResult> GetDefinitions() => Ok(await definitionService.GetDefinitionsAsync());

    [HttpPost("workflow-definitions")]
    public async Task<IActionResult> UpsertDefinition([FromBody] UpsertWorkflowDefinitionRequest request) =>
        Ok(new { workflowDefinitionId = await definitionService.UpsertDefinitionAsync(request, currentUser.UserId) });

    [HttpPost("workflow-definitions/{workflowDefinitionId:int}/versions")]
    public async Task<IActionResult> CreateVersion(int workflowDefinitionId) =>
        Ok(new { workflowVersionId = await definitionService.CreateVersionAsync(workflowDefinitionId, currentUser.UserId) });

    [HttpGet("workflow-versions/{workflowVersionId:int}")]
    public async Task<IActionResult> GetVersionDetail(int workflowVersionId)
    {
        var detail = await definitionService.GetVersionDetailAsync(workflowVersionId);
        return detail is null ? NotFound() : Ok(detail);
    }

    [HttpPost("workflow-versions/{workflowVersionId:int}/publish")]
    public async Task<IActionResult> PublishVersion(int workflowVersionId)
    {
        await definitionService.PublishVersionAsync(workflowVersionId, currentUser.UserId);
        return NoContent();
    }

    [HttpPost("workflow-versions/{workflowVersionId:int}/stages")]
    public async Task<IActionResult> UpsertStage(int workflowVersionId, [FromBody] UpsertStageRequest request) =>
        Ok(new { stageId = await definitionService.UpsertStageAsync(workflowVersionId, request, currentUser.UserId) });

    [HttpPost("workflow-versions/{workflowVersionId:int}/transitions")]
    public async Task<IActionResult> UpsertTransition(int workflowVersionId, [FromBody] UpsertTransitionRequest request) =>
        Ok(new { transitionId = await definitionService.UpsertTransitionAsync(workflowVersionId, request, currentUser.UserId) });

    [HttpPost("workflow-versions/{workflowVersionId:int}/parallel-groups")]
    public async Task<IActionResult> UpsertParallelGroup(int workflowVersionId, [FromBody] UpsertParallelGroupRequest request) =>
        Ok(new { parallelGroupId = await definitionService.UpsertParallelGroupAsync(workflowVersionId, request, currentUser.UserId) });

    [HttpPost("approval-groups")]
    public async Task<IActionResult> UpsertApprovalGroup([FromBody] UpsertApprovalGroupRequest request) =>
        Ok(new { approvalGroupId = await definitionService.UpsertApprovalGroupAsync(request, currentUser.UserId) });

    [HttpPost("approval-groups/{approvalGroupId:int}/members")]
    public async Task<IActionResult> UpsertApprovalGroupMember(int approvalGroupId, [FromBody] UpsertApprovalGroupMemberRequest request) =>
        Ok(new { approvalGroupMemberId = await definitionService.UpsertApprovalGroupMemberAsync(approvalGroupId, request, currentUser.UserId) });

    [HttpPost("approval-rules")]
    public async Task<IActionResult> UpsertApprovalRule([FromBody] UpsertApprovalRuleRequest request) =>
        Ok(new { approvalRuleId = await definitionService.UpsertApprovalRuleAsync(request, currentUser.UserId) });

    [HttpPost("return-rules")]
    public async Task<IActionResult> UpsertReturnRule([FromBody] UpsertReturnRuleRequest request) =>
        Ok(new { returnRuleId = await definitionService.UpsertReturnRuleAsync(request, currentUser.UserId) });
}
