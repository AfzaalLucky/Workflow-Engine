import type {
  ActOnTaskResult,
  ApprovalActionEntry,
  ApprovalGroup,
  ApprovalGroupMember,
  ApprovalRule,
  ApprovalTask,
  InstanceStatusResult,
  LeasingCommission,
  LoginResponse,
  ParallelGroup,
  PurchaseRequest,
  ReturnRule,
  Stage,
  TaskDetailResult,
  Transition,
  WorkflowDefinition,
  WorkflowVersionDetail,
} from "./types";

const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:5160/api";

// Set by AuthContext on login/logout/hydrate -- kept here (rather than
// threaded through every call) since the client has a single active
// session at a time.
let authToken: string | null = null;
export function setAuthToken(token: string | null) {
  authToken = token;
}

class ApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const headers = new Headers(init?.headers);
  headers.set("Content-Type", "application/json");
  if (authToken) headers.set("Authorization", `Bearer ${authToken}`);

  const response = await fetch(`${BASE_URL}${path}`, { ...init, headers });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new ApiError(response.status, body || response.statusText);
  }
  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

export const api = {
  login: (username: string, password: string) =>
    request<LoginResponse>("/auth/login", { method: "POST", body: JSON.stringify({ username, password }) }),

  getMyTasks: () => request<ApprovalTask[]>("/tasks/my"),
  getTaskDetail: (taskId: number) => request<TaskDetailResult>(`/tasks/${taskId}`),
  approveTask: (taskId: number, comments: string) =>
    request<ActOnTaskResult>(`/tasks/${taskId}/approve`, { method: "POST", body: JSON.stringify({ comments }) }),
  rejectTask: (taskId: number, comments: string) =>
    request<ActOnTaskResult>(`/tasks/${taskId}/reject`, { method: "POST", body: JSON.stringify({ comments }) }),
  returnTask: (taskId: number, comments: string, returnToStageId: number | null) =>
    request<ActOnTaskResult>(`/tasks/${taskId}/return`, {
      method: "POST",
      body: JSON.stringify({ comments, returnToStageId }),
    }),

  getInstanceStatus: (instanceId: string) => request<InstanceStatusResult>(`/workflow-instances/${instanceId}`),
  getInstanceHistory: (instanceId: string) =>
    request<ApprovalActionEntry[]>(`/workflow-instances/${instanceId}/history`),
  resumeInstance: (instanceId: string, updatedContextDataJson: string | null) =>
    request<void>(`/workflow-instances/${instanceId}/resume`, {
      method: "POST",
      body: JSON.stringify({ updatedContextDataJson }),
    }),

  createPurchaseRequest: (data: { title: string; description: string; amount: number; department: string }) =>
    request<PurchaseRequest>("/purchase-requests", { method: "POST", body: JSON.stringify(data) }),
  getMyPurchaseRequests: () => request<PurchaseRequest[]>("/purchase-requests/mine"),
  getPurchaseRequest: (id: number) => request<PurchaseRequest>(`/purchase-requests/${id}`),

  createLeasingCommission: (data: { lesseeName: string; commissionAmount: number; branch: string; notes: string }) =>
    request<LeasingCommission>("/leasing-commissions", { method: "POST", body: JSON.stringify(data) }),
  getMyLeasingCommissions: () => request<LeasingCommission[]>("/leasing-commissions/mine"),
  getLeasingCommission: (id: number) => request<LeasingCommission>(`/leasing-commissions/${id}`),

  admin: {
    getDefinitions: () => request<WorkflowDefinition[]>("/admin/workflow-definitions"),
    upsertDefinition: (data: { code: string; name: string; description: string | null; isActive: boolean }) =>
      request<{ workflowDefinitionId: number }>("/admin/workflow-definitions", {
        method: "POST",
        body: JSON.stringify(data),
      }),
    createVersion: (workflowDefinitionId: number) =>
      request<{ workflowVersionId: number }>(`/admin/workflow-definitions/${workflowDefinitionId}/versions`, {
        method: "POST",
      }),
    getVersionDetail: (workflowVersionId: number) =>
      request<WorkflowVersionDetail>(`/admin/workflow-versions/${workflowVersionId}`),
    publishVersion: (workflowVersionId: number) =>
      request<void>(`/admin/workflow-versions/${workflowVersionId}/publish`, { method: "POST" }),
    upsertStage: (workflowVersionId: number, data: Partial<Stage>) =>
      request<{ stageId: number }>(`/admin/workflow-versions/${workflowVersionId}/stages`, {
        method: "POST",
        body: JSON.stringify(data),
      }),
    upsertTransition: (workflowVersionId: number, data: Partial<Transition>) =>
      request<{ transitionId: number }>(`/admin/workflow-versions/${workflowVersionId}/transitions`, {
        method: "POST",
        body: JSON.stringify(data),
      }),
    upsertParallelGroup: (workflowVersionId: number, data: Partial<ParallelGroup>) =>
      request<{ parallelGroupId: number }>(`/admin/workflow-versions/${workflowVersionId}/parallel-groups`, {
        method: "POST",
        body: JSON.stringify(data),
      }),
    upsertApprovalGroup: (data: Partial<ApprovalGroup>) =>
      request<{ approvalGroupId: number }>("/admin/approval-groups", { method: "POST", body: JSON.stringify(data) }),
    upsertApprovalGroupMember: (approvalGroupId: number, data: Partial<ApprovalGroupMember>) =>
      request<{ approvalGroupMemberId: number }>(`/admin/approval-groups/${approvalGroupId}/members`, {
        method: "POST",
        body: JSON.stringify(data),
      }),
    upsertApprovalRule: (data: Partial<ApprovalRule>) =>
      request<{ approvalRuleId: number }>("/admin/approval-rules", { method: "POST", body: JSON.stringify(data) }),
    upsertReturnRule: (data: Partial<ReturnRule>) =>
      request<{ returnRuleId: number }>("/admin/return-rules", { method: "POST", body: JSON.stringify(data) }),
  },
};
