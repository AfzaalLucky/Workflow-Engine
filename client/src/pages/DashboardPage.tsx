import { Link } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

export function DashboardPage() {
  const { session } = useAuth();

  return (
    <div className="dashboard-page">
      <h1>Welcome, {session?.displayName}</h1>
      <p>
        Roles: {session?.roles.length ? session.roles.join(", ") : <em>none</em>}
      </p>

      <div className="dashboard-links">
        <Link to="/tasks" className="dashboard-card">
          <h2>My Tasks</h2>
          <p>Review and act on approvals assigned to you.</p>
        </Link>
        <Link to="/requests/new" className="dashboard-card">
          <h2>New Purchase Request</h2>
          <p>Submit a request and watch it move through the workflow.</p>
        </Link>
        <Link to="/requests/mine" className="dashboard-card">
          <h2>My Requests</h2>
          <p>Track the requests you've submitted.</p>
        </Link>
        <Link to="/leasing-commissions/new" className="dashboard-card">
          <h2>New Leasing Commission</h2>
          <p>Submit a leasing commission for approval.</p>
        </Link>
        <Link to="/leasing-commissions/mine" className="dashboard-card">
          <h2>My Leasing Commissions</h2>
          <p>Track the leasing commissions you've submitted.</p>
        </Link>
      </div>
    </div>
  );
}
