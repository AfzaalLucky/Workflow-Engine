using System.Data;

namespace WorkflowEngine.Infrastructure.Data;

public interface ISqlConnectionFactory
{
    IDbConnection CreateOpenConnection();
}
