// Mirrors the C# DTOs in WorkflowEngine.Application/Domain 1:1. Kept as a
// hand-written file (no codegen) since the API surface is small enough
// that this is less overhead than wiring up a generator.

export interface LoginResponse {
  token: string;
  expiresAt: string;
  userId: string;
  displayName: string;
  roles: string[];
}

export interface ApprovalTask {
  approvalTaskId: number;
  instanceStageId: number;
  workflowInstanceId: string;
  approvalRuleId: number;
  assignedToUserId: string | null;
  assignedToRoleCode: string | null;
  assignedToGroupId: number | null;
  status: string;
  completedByUserId: string | null;
  comments: string | null;
  createdAt: string;
  completedAt: string | null;
  stageKey: string | null;
  stageName: string | null;
  stageType: string | null;
  businessEntityType: string | null;
  businessEntityId: string | null;
  contextDataJson: string | null;
  instanceStatus: string | null;
  workflowDefinitionCode: string | null;
  workflowDefinitionName: string | null;
}

export interface ReturnOption {
  fromStageId: number;
  toStageId: number;
  toStageName: string;
  requireComment: boolean;
}

export interface TaskDetailResult {
  task: ApprovalTask;
  returnOptions: ReturnOption[];
}

export interface ActOnTaskResult {
  workflowInstanceId: string;
  needsRouting: boolean;
  routingFromStageId: number | null;
}

export interface WorkflowInstance {
  workflowInstanceId: string;
  workflowVersionId: number;
  businessEntityType: string;
  businessEntityId: string;
  currentStageId: number | null;
  currentStageKey: string | null;
  currentStageName: string | null;
  status: string;
  contextDataJson: string | null;
  startedByUserId: string;
  startedAt: string;
  completedAt: string | null;
  workflowDefinitionCode: string | null;
  workflowDefinitionName: string | null;
  versionNumber: number;
}

export interface PendingTaskSummary {
  approvalTaskId: number;
  status: string;
  assignedToUserId: string | null;
  assignedToRoleCode: string | null;
  assignedToGroupId: number | null;
  stageName: string;
}

export interface InstanceStatusResult {
  instance: WorkflowInstance;
  pendingTasks: PendingTaskSummary[];
}

export interface ApprovalActionEntry {
  approvalActionId: number;
  actionType: string;
  actorUserId: string;
  actorDisplayName: string | null;
  actionAt: string;
  comments: string | null;
  oldStatus: string | null;
  newStatus: string | null;
  oldStageName: string | null;
  newStageName: string | null;
}

export interface PurchaseRequest {
  purchaseRequestId: number;
  workflowInstanceId: string | null;
  requestedByUserId: string;
  title: string;
  description: string | null;
  amount: number;
  department: string;
  createdAt: string;
  workflowStatus: string | null;
  currentStageName: string | null;
}

export interface LeasingCommission {
  leasingCommissionId: number;
  workflowInstanceId: string | null;
  requestedByUserId: string;
  lesseeName: string;
  commissionAmount: number;
  branch: string;
  notes: string | null;
  createdAt: string;
  workflowStatus: string | null;
  currentStageName: string | null;
}

// --- Admin / designer metadata ---

export interface WorkflowDefinition {
  workflowDefinitionId: number;
  code: string;
  name: string;
  description: string | null;
  isActive: boolean;
  publishedVersionId: number | null;
  publishedVersionNumber: number | null;
}

export interface WorkflowVersion {
  workflowVersionId: number;
  workflowDefinitionId: number;
  versionNumber: number;
  status: string;
  publishedAt: string | null;
  createdAt: string;
}

export interface Stage {
  stageId: number;
  workflowVersionId: number;
  stageKey: string;
  name: string;
  stageOrder: number;
  stageType: string;
  parallelGroupId: number | null;
  isInitial: boolean;
  isFinal: boolean;
}

export interface Transition {
  transitionId: number;
  workflowVersionId: number;
  fromStageId: number;
  toStageId: number;
  conditionExpression: string | null;
  priority: number;
  isDefault: boolean;
}

export interface ParallelGroup {
  parallelGroupId: number;
  workflowVersionId: number;
  code: string;
  name: string;
  joinType: string;
  minRequiredApprovals: number | null;
}

export interface ApprovalRule {
  approvalRuleId: number;
  stageId: number;
  approverType: string;
  specificUserId: string | null;
  approverRoleCode: string | null;
  approvalGroupId: number | null;
  requiredCount: number;
}

export interface ReturnRule {
  returnRuleId: number;
  fromStageId: number;
  toStageId: number;
  toStageName: string | null;
  resetApprovalsOnReturn: boolean;
  requireComment: boolean;
}

export interface ApprovalGroup {
  approvalGroupId: number;
  code: string;
  name: string;
  isActive: boolean;
}

export interface ApprovalGroupMember {
  approvalGroupMemberId: number;
  approvalGroupId: number;
  memberType: string;
  userId: string | null;
  roleCode: string | null;
  isActive: boolean;
}

export interface WorkflowVersionDetail {
  version: WorkflowVersion;
  stages: Stage[];
  transitions: Transition[];
  parallelGroups: ParallelGroup[];
  approvalRules: ApprovalRule[];
  returnRules: ReturnRule[];
  approvalGroups: ApprovalGroup[];
  approvalGroupMembers: ApprovalGroupMember[];
}
