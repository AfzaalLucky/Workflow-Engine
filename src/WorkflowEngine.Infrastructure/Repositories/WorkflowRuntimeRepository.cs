using System.Data;
using Dapper;
using WorkflowEngine.Domain.Entities;
using WorkflowEngine.Infrastructure.Data;

namespace WorkflowEngine.Infrastructure.Repositories;

public class WorkflowRuntimeRepository(ISqlConnectionFactory connectionFactory) : IWorkflowRuntimeRepository
{
    public async Task<StartInstanceResult> StartWorkflowInstanceAsync(
        string workflowDefinitionCode, string businessEntityType, string businessEntityId,
        string? contextDataJson, Guid startedByUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("WorkflowDefinitionCode", workflowDefinitionCode);
        parameters.Add("BusinessEntityType", businessEntityType);
        parameters.Add("BusinessEntityId", businessEntityId);
        parameters.Add("ContextDataJson", contextDataJson);
        parameters.Add("StartedByUserId", startedByUserId);
        parameters.Add("WorkflowInstanceId", dbType: DbType.Guid, direction: ParameterDirection.Output);
        parameters.Add("InitialStageId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_StartWorkflowInstance", parameters, commandType: CommandType.StoredProcedure);

        return new StartInstanceResult
        {
            WorkflowInstanceId = parameters.Get<Guid>("WorkflowInstanceId"),
            InitialStageId = parameters.Get<int>("InitialStageId"),
        };
    }

    public async Task AdvanceToStageAsync(Guid workflowInstanceId, int toStageId, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        await connection.ExecuteAsync("dbo.wf_AdvanceToStage", new
        {
            WorkflowInstanceId = workflowInstanceId,
            ToStageId = toStageId,
            ActorUserId = actorUserId
        }, commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<CandidateTransition>> GetCandidateTransitionsAsync(int fromStageId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var result = await connection.QueryAsync<CandidateTransition>(
            "dbo.wf_GetCandidateTransitions", new { FromStageId = fromStageId }, commandType: CommandType.StoredProcedure);
        return result.ToList();
    }

    public async Task<ActOnTaskResult> ActOnTaskAsync(
        long approvalTaskId, Guid actorUserId, IEnumerable<string> actorRoleCodes,
        string action, string? comments, int? returnToStageId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("ApprovalTaskId", approvalTaskId);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("ActorRoleCodes", RoleCodeTableValuedParameter.AsParameter(actorRoleCodes));
        parameters.Add("Action", action);
        parameters.Add("Comments", comments);
        parameters.Add("ReturnToStageId", returnToStageId);
        parameters.Add("WorkflowInstanceId", dbType: DbType.Guid, direction: ParameterDirection.Output);
        parameters.Add("NeedsRouting", dbType: DbType.Boolean, direction: ParameterDirection.Output);
        parameters.Add("RoutingFromStageId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_ActOnTask", parameters, commandType: CommandType.StoredProcedure);

        return new ActOnTaskResult
        {
            WorkflowInstanceId = parameters.Get<Guid>("WorkflowInstanceId"),
            NeedsRouting = parameters.Get<bool>("NeedsRouting"),
            RoutingFromStageId = parameters.Get<int?>("RoutingFromStageId"),
        };
    }

    public async Task<ResumeInstanceResult> ResumeWorkflowInstanceAsync(
        Guid workflowInstanceId, Guid actorUserId, string? updatedContextDataJson)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("WorkflowInstanceId", workflowInstanceId);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("UpdatedContextDataJson", updatedContextDataJson);
        parameters.Add("CurrentStageId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("NeedsRouting", dbType: DbType.Boolean, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_ResumeWorkflowInstance", parameters, commandType: CommandType.StoredProcedure);

        return new ResumeInstanceResult
        {
            CurrentStageId = parameters.Get<int>("CurrentStageId"),
            NeedsRouting = parameters.Get<bool>("NeedsRouting"),
        };
    }

    public async Task<IReadOnlyList<ApprovalTask>> GetMyPendingTasksAsync(Guid userId, IEnumerable<string> roleCodes)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("UserId", userId);
        parameters.Add("RoleCodes", RoleCodeTableValuedParameter.AsParameter(roleCodes));

        var result = await connection.QueryAsync<ApprovalTask>(
            "dbo.wf_GetMyPendingTasks", parameters, commandType: CommandType.StoredProcedure);
        return result.ToList();
    }

    public async Task<TaskDetailResult?> GetTaskDetailAsync(long approvalTaskId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        using var multi = await connection.QueryMultipleAsync(
            "dbo.wf_GetTaskDetail", new { ApprovalTaskId = approvalTaskId }, commandType: CommandType.StoredProcedure);

        var task = await multi.ReadSingleOrDefaultAsync<ApprovalTask>();
        if (task is null) return null;

        var returnOptions = (await multi.ReadAsync<ReturnOption>()).ToList();
        return new TaskDetailResult { Task = task, ReturnOptions = returnOptions };
    }

    public async Task<InstanceStatusResult?> GetWorkflowInstanceStatusAsync(Guid workflowInstanceId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        using var multi = await connection.QueryMultipleAsync(
            "dbo.wf_GetWorkflowInstanceStatus", new { WorkflowInstanceId = workflowInstanceId }, commandType: CommandType.StoredProcedure);

        var instance = await multi.ReadSingleOrDefaultAsync<WorkflowInstance>();
        if (instance is null) return null;

        var pendingTasks = (await multi.ReadAsync<PendingTaskSummary>()).ToList();
        return new InstanceStatusResult { Instance = instance, PendingTasks = pendingTasks };
    }

    public async Task<IReadOnlyList<ApprovalActionEntry>> GetWorkflowInstanceHistoryAsync(Guid workflowInstanceId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var result = await connection.QueryAsync<ApprovalActionEntry>(
            "dbo.wf_GetWorkflowInstanceHistory", new { WorkflowInstanceId = workflowInstanceId }, commandType: CommandType.StoredProcedure);
        return result.ToList();
    }
}
