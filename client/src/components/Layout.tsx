import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

export function Layout() {
  const { session, logout, hasRole } = useAuth();

  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="app-header-brand">Workflow Engine</div>
        <nav className="app-nav">
          <NavLink to="/" end>
            Dashboard
          </NavLink>
          <NavLink to="/tasks">My Tasks</NavLink>
          <NavLink to="/requests/mine">My Requests</NavLink>
          <NavLink to="/requests/new">New Request</NavLink>
          <NavLink to="/leasing-commissions/mine">My Leasing Commissions</NavLink>
          <NavLink to="/leasing-commissions/new">New Leasing Commission</NavLink>
          {hasRole("WorkflowAdmin") && <NavLink to="/admin/workflows">Admin</NavLink>}
        </nav>
        <div className="app-header-user">
          <span>{session?.displayName}</span>
          <button onClick={logout}>Log out</button>
        </div>
      </header>
      <main className="app-content">
        <Outlet />
      </main>
    </div>
  );
}
