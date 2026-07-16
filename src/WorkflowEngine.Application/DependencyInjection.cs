using Microsoft.Extensions.DependencyInjection;
using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Services;

namespace WorkflowEngine.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddWorkflowApplication(this IServiceCollection services)
    {
        services.AddScoped<IWorkflowRoutingService, WorkflowRoutingService>();
        services.AddScoped<IWorkflowInstanceService, WorkflowInstanceService>();
        services.AddScoped<IApprovalTaskService, ApprovalTaskService>();
        services.AddScoped<IWorkflowDefinitionService, WorkflowDefinitionService>();

        return services;
    }
}
