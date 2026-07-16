import type { ReactNode } from "react";
import { Navigate } from "react-router-dom";
import { useAuth } from "./AuthContext";

export function RequireAuth({ children, roles }: { children: ReactNode; roles?: string[] }) {
  const { isAuthenticated, hasRole } = useAuth();

  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (roles && !roles.some(hasRole)) return <Navigate to="/" replace />;

  return <>{children}</>;
}
