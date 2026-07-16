import { Navigate, Route, Routes } from "react-router-dom";
import { RequireAuth } from "./auth/RequireAuth";
import { Layout } from "./components/Layout";
import { AdminWorkflowsPage } from "./pages/AdminWorkflowsPage";
import { DashboardPage } from "./pages/DashboardPage";
import { InstanceHistoryPage } from "./pages/InstanceHistoryPage";
import { LoginPage } from "./pages/LoginPage";
import { MyLeasingCommissionsPage } from "./pages/MyLeasingCommissionsPage";
import { MyRequestsPage } from "./pages/MyRequestsPage";
import { NewLeasingCommissionPage } from "./pages/NewLeasingCommissionPage";
import { NewRequestPage } from "./pages/NewRequestPage";
import { TaskDetailPage } from "./pages/TaskDetailPage";
import { TasksInboxPage } from "./pages/TasksInboxPage";

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />

      <Route
        element={
          <RequireAuth>
            <Layout />
          </RequireAuth>
        }
      >
        <Route path="/" element={<DashboardPage />} />
        <Route path="/tasks" element={<TasksInboxPage />} />
        <Route path="/tasks/:taskId" element={<TaskDetailPage />} />
        <Route path="/requests/new" element={<NewRequestPage />} />
        <Route path="/requests/mine" element={<MyRequestsPage />} />
        <Route path="/leasing-commissions/new" element={<NewLeasingCommissionPage />} />
        <Route path="/leasing-commissions/mine" element={<MyLeasingCommissionsPage />} />
        <Route path="/instances/:instanceId" element={<InstanceHistoryPage />} />
        <Route
          path="/admin/workflows"
          element={
            <RequireAuth roles={["WorkflowAdmin"]}>
              <AdminWorkflowsPage />
            </RequireAuth>
          }
        />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
