import { useState, type SyntheticEvent } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

const DEMO_ACCOUNTS = [
  "requester / Requester@123!",
  "manager / Manager@123!",
  "finance / Finance@123!",
  "legal / Legal@123!",
  "procurement / Procurement@123!",
  "director / Director@123!",
  "admin / Admin@123!",
  "leasingofficer / LeasingOfficer@123!",
  "leasingfinance / LeasingFinance@123!",
  "leasingcc / LeasingCC@123!",
  "auditor / Auditor@123!",
  "leasingclearance / LeasingClearance@123!",
];

export function LoginPage() {
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (isAuthenticated) {
    const from = (location.state as { from?: string })?.from ?? "/";
    return <Navigate to={from} replace />;
  }

  const handleSubmit = async (event: SyntheticEvent) => {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await login(username, password);
      navigate("/");
    } catch {
      setError("Invalid username or password.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="login-page">
      <form className="login-form" onSubmit={handleSubmit}>
        <h1>Workflow Engine</h1>
        <label>
          Username
          <input value={username} onChange={(e) => setUsername(e.target.value)} autoFocus />
        </label>
        <label>
          Password
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        {error && <p className="form-error">{error}</p>}
        <button type="submit" disabled={submitting}>
          {submitting ? "Signing in..." : "Sign in"}
        </button>

        <div className="demo-accounts">
          <p>Demo accounts (seeded, matching the Purchase Request workflow roles):</p>
          <ul>
            {DEMO_ACCOUNTS.map((account) => (
              <li key={account}>{account}</li>
            ))}
          </ul>
        </div>
      </form>
    </div>
  );
}
