import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, setAuthToken } from "../api/apiClient";

interface AuthSession {
  token: string;
  expiresAt: string;
  userId: string;
  displayName: string;
  roles: string[];
}

interface AuthContextValue {
  session: AuthSession | null;
  isAuthenticated: boolean;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
  hasRole: (role: string) => boolean;
}

const STORAGE_KEY = "workflowEngine.session";

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

function loadStoredSession(): AuthSession | null {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return null;

  const session = JSON.parse(raw) as AuthSession;
  if (new Date(session.expiresAt) <= new Date()) {
    localStorage.removeItem(STORAGE_KEY);
    return null;
  }
  return session;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<AuthSession | null>(() => {
    const stored = loadStoredSession();
    if (stored) setAuthToken(stored.token);
    return stored;
  });

  useEffect(() => {
    setAuthToken(session?.token ?? null);
  }, [session]);

  const login = async (username: string, password: string) => {
    const response = await api.login(username, password);
    const newSession: AuthSession = {
      token: response.token,
      expiresAt: response.expiresAt,
      userId: response.userId,
      displayName: response.displayName,
      roles: response.roles,
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(newSession));
    setSession(newSession);
  };

  const logout = () => {
    localStorage.removeItem(STORAGE_KEY);
    setSession(null);
  };

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      isAuthenticated: session !== null,
      login,
      logout,
      hasRole: (role: string) => session?.roles.includes(role) ?? false,
    }),
    [session],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used within an AuthProvider.");
  return context;
}
