using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Application.Services;

namespace WorkflowEngine.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/workflow-instances")]
public class WorkflowInstancesController(
    IWorkflowInstanceService instanceService,
    ICurrentUserContext currentUser) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Start([FromBody] StartWorkflowInstanceRequest request)
    {
        var instanceId = await instanceService.StartInstanceAsync(request, currentUser.UserId);
        return CreatedAtAction(nameof(GetStatus), new { workflowInstanceId = instanceId }, new { workflowInstanceId = instanceId });
    }

    [HttpGet("{workflowInstanceId:guid}")]
    public async Task<IActionResult> GetStatus(Guid workflowInstanceId)
    {
        var status = await instanceService.GetInstanceStatusAsync(workflowInstanceId);
        return status is null ? NotFound() : Ok(status);
    }

    [HttpGet("{workflowInstanceId:guid}/history")]
    public async Task<IActionResult> GetHistory(Guid workflowInstanceId)
    {
        var history = await instanceService.GetInstanceHistoryAsync(workflowInstanceId);
        return Ok(history);
    }

    [HttpPost("{workflowInstanceId:guid}/resume")]
    public async Task<IActionResult> Resume(Guid workflowInstanceId, [FromBody] ResumeWorkflowInstanceRequest request)
    {
        await instanceService.ResumeInstanceAsync(workflowInstanceId, request, currentUser.UserId);
        return NoContent();
    }
}
