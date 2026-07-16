using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Application.Services;

namespace WorkflowEngine.Api.Samples.PurchaseRequests;

// Demonstrates how a consuming application wires its own business process
// onto the generic engine: create the business row, start a workflow
// instance for it, link the two. No wf_* schema or engine code changes
// were needed to add this process.
[ApiController]
[Authorize]
[Route("api/purchase-requests")]
public class PurchaseRequestsController(
    IPurchaseRequestRepository purchaseRequests,
    IWorkflowInstanceService instanceService,
    ICurrentUserContext currentUser) : ControllerBase
{
    private const string WorkflowDefinitionCode = "PURCHASE_REQUEST";

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreatePurchaseRequestRequest request)
    {
        var purchaseRequestId = await purchaseRequests.CreateAsync(
            currentUser.UserId, request.Title, request.Description, request.Amount, request.Department);

        var contextDataJson = JsonSerializer.Serialize(new { Amount = request.Amount, Department = request.Department });
        var workflowInstanceId = await instanceService.StartInstanceAsync(
            new StartWorkflowInstanceRequest(WorkflowDefinitionCode, "PurchaseRequest", purchaseRequestId.ToString(), contextDataJson),
            currentUser.UserId);

        await purchaseRequests.SetWorkflowInstanceAsync(purchaseRequestId, workflowInstanceId);

        var created = await purchaseRequests.GetAsync(purchaseRequestId);
        return CreatedAtAction(nameof(Get), new { purchaseRequestId }, created);
    }

    [HttpGet("{purchaseRequestId:int}")]
    public async Task<IActionResult> Get(int purchaseRequestId)
    {
        var request = await purchaseRequests.GetAsync(purchaseRequestId);
        return request is null ? NotFound() : Ok(request);
    }

    [HttpGet("mine")]
    public async Task<IActionResult> GetMine()
    {
        var mine = await purchaseRequests.GetMineAsync(currentUser.UserId);
        return Ok(mine);
    }
}
