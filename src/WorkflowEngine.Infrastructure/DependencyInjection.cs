using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using WorkflowEngine.Infrastructure.Data;
using WorkflowEngine.Infrastructure.Repositories;

namespace WorkflowEngine.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddWorkflowInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<WorkflowDbOptions>(options =>
            options.ConnectionString = configuration.GetConnectionString("WorkflowEngineDb")
                ?? throw new InvalidOperationException("Missing ConnectionStrings:WorkflowEngineDb configuration."));

        services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
        services.AddScoped<IWorkflowRuntimeRepository, WorkflowRuntimeRepository>();
        services.AddScoped<IWorkflowMetadataRepository, WorkflowMetadataRepository>();

        return services;
    }
}
