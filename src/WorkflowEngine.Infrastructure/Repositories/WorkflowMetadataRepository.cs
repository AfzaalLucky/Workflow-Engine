using System.Data;
using Dapper;
using WorkflowEngine.Domain.Entities;
using WorkflowEngine.Infrastructure.Data;

namespace WorkflowEngine.Infrastructure.Repositories;

public class WorkflowMetadataRepository(ISqlConnectionFactory connectionFactory) : IWorkflowMetadataRepository
{
    public async Task<IReadOnlyList<WorkflowDefinition>> GetWorkflowDefinitionsAsync()
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var result = await connection.QueryAsync<WorkflowDefinition>(
            "dbo.wf_GetWorkflowDefinitions", commandType: CommandType.StoredProcedure);
        return result.ToList();
    }

    public async Task<WorkflowVersionDetail?> GetWorkflowVersionDetailAsync(int workflowVersionId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        using var multi = await connection.QueryMultipleAsync(
            "dbo.wf_GetWorkflowVersionDetail", new { WorkflowVersionId = workflowVersionId }, commandType: CommandType.StoredProcedure);

        var version = await multi.ReadSingleOrDefaultAsync<WorkflowVersion>();
        if (version is null) return null;

        return new WorkflowVersionDetail
        {
            Version = version,
            Stages = (await multi.ReadAsync<Stage>()).ToList(),
            Transitions = (await multi.ReadAsync<Transition>()).ToList(),
            ParallelGroups = (await multi.ReadAsync<ParallelGroup>()).ToList(),
            ApprovalRules = (await multi.ReadAsync<ApprovalRule>()).ToList(),
            ReturnRules = (await multi.ReadAsync<ReturnRule>()).ToList(),
            ApprovalGroups = (await multi.ReadAsync<ApprovalGroup>()).ToList(),
            ApprovalGroupMembers = (await multi.ReadAsync<ApprovalGroupMember>()).ToList(),
        };
    }

    public async Task<int> UpsertWorkflowDefinitionAsync(string code, string name, string? description, bool isActive, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("Code", code);
        parameters.Add("Name", name);
        parameters.Add("Description", description);
        parameters.Add("IsActive", isActive);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("WorkflowDefinitionId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_UpsertWorkflowDefinition", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("WorkflowDefinitionId");
    }

    public async Task<int> CreateWorkflowVersionAsync(int workflowDefinitionId, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("WorkflowDefinitionId", workflowDefinitionId);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("WorkflowVersionId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_CreateWorkflowVersion", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("WorkflowVersionId");
    }

    public async Task PublishWorkflowVersionAsync(int workflowVersionId, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        await connection.ExecuteAsync("dbo.wf_PublishWorkflowVersion",
            new { WorkflowVersionId = workflowVersionId, ActorUserId = actorUserId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> UpsertStageAsync(int workflowVersionId, string stageKey, string name, int stageOrder,
        string stageType, int? parallelGroupId, bool isInitial, bool isFinal, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("WorkflowVersionId", workflowVersionId);
        parameters.Add("StageKey", stageKey);
        parameters.Add("Name", name);
        parameters.Add("StageOrder", stageOrder);
        parameters.Add("StageType", stageType);
        parameters.Add("ParallelGroupId", parallelGroupId);
        parameters.Add("IsInitial", isInitial);
        parameters.Add("IsFinal", isFinal);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("StageId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_UpsertStage", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("StageId");
    }

    public async Task<int> UpsertTransitionAsync(int? transitionId, int workflowVersionId, int fromStageId, int toStageId,
        string? conditionExpression, int priority, bool isDefault, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("TransitionId", transitionId);
        parameters.Add("WorkflowVersionId", workflowVersionId);
        parameters.Add("FromStageId", fromStageId);
        parameters.Add("ToStageId", toStageId);
        parameters.Add("ConditionExpression", conditionExpression);
        parameters.Add("Priority", priority);
        parameters.Add("IsDefault", isDefault);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("ResultTransitionId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_UpsertTransition", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("ResultTransitionId");
    }

    public async Task<int> UpsertParallelGroupAsync(int workflowVersionId, string code, string name, string joinType,
        int? minRequiredApprovals, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("WorkflowVersionId", workflowVersionId);
        parameters.Add("Code", code);
        parameters.Add("Name", name);
        parameters.Add("JoinType", joinType);
        parameters.Add("MinRequiredApprovals", minRequiredApprovals);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("ParallelGroupId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_UpsertParallelGroup", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("ParallelGroupId");
    }

    public async Task<int> UpsertApprovalGroupAsync(string code, string name, bool isActive, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("Code", code);
        parameters.Add("Name", name);
        parameters.Add("IsActive", isActive);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("ApprovalGroupId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_UpsertApprovalGroup", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("ApprovalGroupId");
    }

    public async Task<int> UpsertApprovalGroupMemberAsync(int approvalGroupId, string memberType, Guid? userId,
        string? roleCode, bool isActive, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("ApprovalGroupId", approvalGroupId);
        parameters.Add("MemberType", memberType);
        parameters.Add("UserId", userId);
        parameters.Add("RoleCode", roleCode);
        parameters.Add("IsActive", isActive);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("ApprovalGroupMemberId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_UpsertApprovalGroupMember", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("ApprovalGroupMemberId");
    }

    public async Task<int> UpsertApprovalRuleAsync(int? approvalRuleId, int stageId, string approverType, Guid? specificUserId,
        string? approverRoleCode, int? approvalGroupId, int requiredCount, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("ApprovalRuleId", approvalRuleId);
        parameters.Add("StageId", stageId);
        parameters.Add("ApproverType", approverType);
        parameters.Add("SpecificUserId", specificUserId);
        parameters.Add("ApproverRoleCode", approverRoleCode);
        parameters.Add("ApprovalGroupId", approvalGroupId);
        parameters.Add("RequiredCount", requiredCount);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("ResultApprovalRuleId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_UpsertApprovalRule", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("ResultApprovalRuleId");
    }

    public async Task<int> UpsertReturnRuleAsync(int? returnRuleId, int fromStageId, int toStageId,
        bool resetApprovalsOnReturn, bool requireComment, Guid actorUserId)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        var parameters = new DynamicParameters();
        parameters.Add("ReturnRuleId", returnRuleId);
        parameters.Add("FromStageId", fromStageId);
        parameters.Add("ToStageId", toStageId);
        parameters.Add("ResetApprovalsOnReturn", resetApprovalsOnReturn);
        parameters.Add("RequireComment", requireComment);
        parameters.Add("ActorUserId", actorUserId);
        parameters.Add("ResultReturnRuleId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await connection.ExecuteAsync("dbo.wf_UpsertReturnRule", parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("ResultReturnRuleId");
    }

    public async Task UpsertUserRefAsync(Guid userId, string displayName, string? email)
    {
        using var connection = connectionFactory.CreateOpenConnection();
        await connection.ExecuteAsync("dbo.wf_UpsertUserRef",
            new { UserId = userId, DisplayName = displayName, Email = email },
            commandType: CommandType.StoredProcedure);
    }
}
