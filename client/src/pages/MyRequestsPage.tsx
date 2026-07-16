import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { api } from "../api/apiClient";

export function MyRequestsPage() {
  const { data: requests, isLoading, error } = useQuery({
    queryKey: ["myPurchaseRequests"],
    queryFn: api.getMyPurchaseRequests,
  });

  if (isLoading) return <p>Loading requests...</p>;
  if (error) return <p className="form-error">Failed to load requests.</p>;

  return (
    <div>
      <h1>My Requests</h1>
      {requests && requests.length === 0 && <p>You haven't submitted any purchase requests yet.</p>}
      {requests && requests.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>Amount</th>
              <th>Department</th>
              <th>Status</th>
              <th>Stage</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {requests.map((request) => (
              <tr key={request.purchaseRequestId}>
                <td>{request.title}</td>
                <td>{request.amount.toLocaleString()}</td>
                <td>{request.department}</td>
                <td>
                  {request.workflowStatus && (
                    <span className={`badge status-${request.workflowStatus}`}>{request.workflowStatus}</span>
                  )}
                </td>
                <td>{request.currentStageName ?? "-"}</td>
                <td>
                  {request.workflowInstanceId && (
                    <Link to={`/instances/${request.workflowInstanceId}`}>View</Link>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
