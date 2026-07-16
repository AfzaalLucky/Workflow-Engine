import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "../../api/apiClient";
import type { ApprovalGroup, ApprovalRule, Stage } from "../../api/types";

export function ApprovalRulesEditor({
  workflowVersionId,
  stages,
  approvalRules,
  approvalGroups,
}: {
  workflowVersionId: number;
  stages: Stage[];
  approvalRules: ApprovalRule[];
  approvalGroups: ApprovalGroup[];
}) {
  const queryClient = useQueryClient();
  const [stageId, setStageId] = useState("");
  const [approverType, setApproverType] = useState("Role");
  const [specificUserId, setSpecificUserId] = useState("");
  const [approverRoleCode, setApproverRoleCode] = useState("");
  const [approvalGroupId, setApprovalGroupId] = useState("");
  const [requiredCount, setRequiredCount] = useState("1");

  const stageName = (id: number) => stages.find((s) => s.stageId === id)?.name ?? id;
  const groupName = (id: number | null) => approvalGroups.find((g) => g.approvalGroupId === id)?.name ?? "";

  const mutation = useMutation({
    mutationFn: () =>
      api.admin.upsertApprovalRule({
        stageId: Number(stageId),
        approverType,
        specificUserId: approverType === "User" ? specificUserId : null,
        approverRoleCode: approverType === "Role" ? approverRoleCode : null,
        approvalGroupId: approverType === "Group" ? Number(approvalGroupId) : null,
        requiredCount: Number(requiredCount),
      }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["adminVersionDetail", workflowVersionId] }),
  });

  return (
    <div className="card">
      <h3>Approval Rules</h3>
      <table>
        <thead>
          <tr>
            <th>Stage</th>
            <th>Approver Type</th>
            <th>Approver</th>
            <th>Required Count</th>
          </tr>
        </thead>
        <tbody>
          {approvalRules.map((r) => (
            <tr key={r.approvalRuleId}>
              <td>{stageName(r.stageId)}</td>
              <td>{r.approverType}</td>
              <td>{r.approverRoleCode ?? groupName(r.approvalGroupId) ?? r.specificUserId}</td>
              <td>{r.requiredCount}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          mutation.mutate();
        }}
        style={{ marginTop: 12, display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8, alignItems: "end" }}
      >
        <label>
          Stage
          <select value={stageId} onChange={(e) => setStageId(e.target.value)} required>
            <option value="">Select...</option>
            {stages.map((s) => (
              <option key={s.stageId} value={s.stageId}>
                {s.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Approver Type
          <select value={approverType} onChange={(e) => setApproverType(e.target.value)}>
            <option value="User">User</option>
            <option value="Role">Role</option>
            <option value="Group">Group</option>
          </select>
        </label>
        {approverType === "User" && (
          <label>
            User Id (GUID)
            <input value={specificUserId} onChange={(e) => setSpecificUserId(e.target.value)} required />
          </label>
        )}
        {approverType === "Role" && (
          <label>
            Role Code
            <input value={approverRoleCode} onChange={(e) => setApproverRoleCode(e.target.value)} required />
          </label>
        )}
        {approverType === "Group" && (
          <label>
            Approval Group
            <select value={approvalGroupId} onChange={(e) => setApprovalGroupId(e.target.value)} required>
              <option value="">Select...</option>
              {approvalGroups.map((g) => (
                <option key={g.approvalGroupId} value={g.approvalGroupId}>
                  {g.name}
                </option>
              ))}
            </select>
          </label>
        )}
        <label>
          Required Count
          <input type="number" min="1" value={requiredCount} onChange={(e) => setRequiredCount(e.target.value)} />
        </label>
        <button className="primary" type="submit" disabled={mutation.isPending}>
          Add / Update Rule
        </button>
      </form>
    </div>
  );
}
