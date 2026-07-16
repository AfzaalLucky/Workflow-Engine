using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Application.Services;

namespace WorkflowEngine.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/tasks")]
public class TasksController(
    IApprovalTaskService taskService,
    ICurrentUserContext currentUser) : ControllerBase
{
    [HttpGet("my")]
    public async Task<IActionResult> GetMyTasks()
    {
        var tasks = await taskService.GetMyTasksAsync(currentUser.UserId, currentUser.Roles);
        return Ok(tasks);
    }

    [HttpGet("{approvalTaskId:long}")]
    public async Task<IActionResult> GetDetail(long approvalTaskId)
    {
        var detail = await taskService.GetTaskDetailAsync(approvalTaskId);
        return detail is null ? NotFound() : Ok(detail);
    }

    [HttpPost("{approvalTaskId:long}/approve")]
    public async Task<IActionResult> Approve(long approvalTaskId, [FromBody] ActOnTaskCommentRequest request) =>
        await ActOnTask(approvalTaskId, new ActOnTaskRequest("Approve", request.Comments, null));

    [HttpPost("{approvalTaskId:long}/reject")]
    public async Task<IActionResult> Reject(long approvalTaskId, [FromBody] ActOnTaskCommentRequest request) =>
        await ActOnTask(approvalTaskId, new ActOnTaskRequest("Reject", request.Comments, null));

    [HttpPost("{approvalTaskId:long}/return")]
    public async Task<IActionResult> Return(long approvalTaskId, [FromBody] ActOnTaskReturnRequest request) =>
        await ActOnTask(approvalTaskId, new ActOnTaskRequest("Return", request.Comments, request.ReturnToStageId));

    private async Task<IActionResult> ActOnTask(long approvalTaskId, ActOnTaskRequest request)
    {
        var result = await taskService.ActOnTaskAsync(approvalTaskId, currentUser.UserId, currentUser.Roles, request);
        return Ok(result);
    }
}

public record ActOnTaskCommentRequest(string? Comments);
public record ActOnTaskReturnRequest(string? Comments, int? ReturnToStageId);
