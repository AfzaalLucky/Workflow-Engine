using Microsoft.Extensions.DependencyInjection;
using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Events;
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
        services.AddScoped<IWorkflowEventProcessor, WorkflowEventProcessor>();

        return services;
    }

    // Registers a host-application reaction to workflow lifecycle events.
    public static IServiceCollection AddWorkflowEventHandler<THandler>(this IServiceCollection services)
        where THandler : class, IWorkflowEventHandler
    {
        services.AddScoped<IWorkflowEventHandler, THandler>();
        return services;
    }
}
