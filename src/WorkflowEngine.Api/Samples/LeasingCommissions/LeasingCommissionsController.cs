using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Dtos;
using WorkflowEngine.Application.Services;

namespace WorkflowEngine.Api.Samples.LeasingCommissions;

// Second proof of genericness alongside Purchase Request: a different
// business process (see LeasingFlow.md), wired onto the same generic
// engine with zero wf_* schema or engine code changes -- only this
// thin business table/controller and the metadata seeded in
// database/seed/seed_leasing_commission_workflow.sql.
[ApiController]
[Authorize]
[Route("api/leasing-commissions")]
public class LeasingCommissionsController(
    ILeasingCommissionRepository leasingCommissions,
    IWorkflowInstanceService instanceService,
    ICurrentUserContext currentUser) : ControllerBase
{
    private const string WorkflowDefinitionCode = "LEASING_COMMISSION";

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateLeasingCommissionRequest request)
    {
        var leasingCommissionId = await leasingCommissions.CreateAsync(
            currentUser.UserId, request.LesseeName, request.CommissionAmount, request.Branch, request.Notes);

        var contextDataJson = JsonSerializer.Serialize(new { request.CommissionAmount, request.Branch });
        var workflowInstanceId = await instanceService.StartInstanceAsync(
            new StartWorkflowInstanceRequest(WorkflowDefinitionCode, "LeasingCommission", leasingCommissionId.ToString(), contextDataJson),
            currentUser.UserId);

        await leasingCommissions.SetWorkflowInstanceAsync(leasingCommissionId, workflowInstanceId);

        var created = await leasingCommissions.GetAsync(leasingCommissionId);
        return CreatedAtAction(nameof(Get), new { leasingCommissionId }, created);
    }

    [HttpGet("{leasingCommissionId:int}")]
    public async Task<IActionResult> Get(int leasingCommissionId)
    {
        var commission = await leasingCommissions.GetAsync(leasingCommissionId);
        return commission is null ? NotFound() : Ok(commission);
    }

    [HttpGet("mine")]
    public async Task<IActionResult> GetMine()
    {
        var mine = await leasingCommissions.GetMineAsync(currentUser.UserId);
        return Ok(mine);
    }
}
