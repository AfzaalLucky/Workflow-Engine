import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { api } from "../api/apiClient";

export function MyLeasingCommissionsPage() {
  const { data: commissions, isLoading, error } = useQuery({
    queryKey: ["myLeasingCommissions"],
    queryFn: api.getMyLeasingCommissions,
  });

  if (isLoading) return <p>Loading leasing commissions...</p>;
  if (error) return <p className="form-error">Failed to load leasing commissions.</p>;

  return (
    <div>
      <h1>My Leasing Commissions</h1>
      {commissions && commissions.length === 0 && <p>You haven't submitted any leasing commissions yet.</p>}
      {commissions && commissions.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>Lessee</th>
              <th>Amount</th>
              <th>Branch</th>
              <th>Status</th>
              <th>Stage</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {commissions.map((c) => (
              <tr key={c.leasingCommissionId}>
                <td>{c.lesseeName}</td>
                <td>{c.commissionAmount.toLocaleString()}</td>
                <td>{c.branch}</td>
                <td>
                  {c.workflowStatus && <span className={`badge status-${c.workflowStatus}`}>{c.workflowStatus}</span>}
                </td>
                <td>{c.currentStageName ?? "-"}</td>
                <td>{c.workflowInstanceId && <Link to={`/instances/${c.workflowInstanceId}`}>View</Link>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
