using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace WorkflowEngine.Infrastructure.Data;

public class WorkflowDbOptions
{
    public string ConnectionString { get; set; } = "";
}

public class SqlConnectionFactory(IOptions<WorkflowDbOptions> options) : ISqlConnectionFactory
{
    private readonly string _connectionString = options.Value.ConnectionString;

    public IDbConnection CreateOpenConnection()
    {
        var connection = new SqlConnection(_connectionString);
        connection.Open();
        return connection;
    }
}
