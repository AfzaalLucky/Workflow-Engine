using System.Data;
using Dapper;

namespace WorkflowEngine.Infrastructure.Data;

// Converts a caller's JWT role claims into the dbo.wf_RoleCodeList table type
// so stored procs can re-validate role/group task eligibility server-side.
public static class RoleCodeTableValuedParameter
{
    public static DataTable ToTable(IEnumerable<string> roleCodes)
    {
        var table = new DataTable();
        table.Columns.Add("RoleCode", typeof(string));
        foreach (var role in roleCodes.Distinct())
            table.Rows.Add(role);
        return table;
    }

    public static SqlMapper.ICustomQueryParameter AsParameter(IEnumerable<string> roleCodes) =>
        ToTable(roleCodes).AsTableValuedParameter("dbo.wf_RoleCodeList");
}
