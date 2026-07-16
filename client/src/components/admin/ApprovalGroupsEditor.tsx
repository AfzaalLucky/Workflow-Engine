import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "../../api/apiClient";
import type { ApprovalGroup, ApprovalGroupMember } from "../../api/types";

// Approval groups are global reference data (not scoped to one workflow
// version), but edits here still invalidate the version-detail query since
// that's what the rest of the admin UI reads them through.
export function ApprovalGroupsEditor({
  workflowVersionId,
  approvalGroups,
  approvalGroupMembers,
}: {
  workflowVersionId: number;
  approvalGroups: ApprovalGroup[];
  approvalGroupMembers: ApprovalGroupMember[];
}) {
  const queryClient = useQueryClient();
  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["adminVersionDetail", workflowVersionId] });

  const [groupCode, setGroupCode] = useState("");
  const [groupName, setGroupName] = useState("");
  const groupMutation = useMutation({
    mutationFn: () => api.admin.upsertApprovalGroup({ code: groupCode, name: groupName, isActive: true }),
    onSuccess: () => {
      invalidate();
      setGroupCode("");
      setGroupName("");
    },
  });

  const [memberGroupId, setMemberGroupId] = useState("");
  const [memberType, setMemberType] = useState("Role");
  const [memberUserId, setMemberUserId] = useState("");
  const [memberRoleCode, setMemberRoleCode] = useState("");
  const memberMutation = useMutation({
    mutationFn: () =>
      api.admin.upsertApprovalGroupMember(Number(memberGroupId), {
        memberType,
        userId: memberType === "User" ? memberUserId : null,
        roleCode: memberType === "Role" ? memberRoleCode : null,
        isActive: true,
      }),
    onSuccess: () => {
      invalidate();
      setMemberRoleCode("");
      setMemberUserId("");
    },
  });

  return (
    <div className="card">
      <h3>Approval Groups</h3>
      <table>
        <thead>
          <tr>
            <th>Code</th>
            <th>Name</th>
            <th>Members</th>
          </tr>
        </thead>
        <tbody>
          {approvalGroups.map((g) => (
            <tr key={g.approvalGroupId}>
              <td>{g.code}</td>
              <td>{g.name}</td>
              <td>
                {approvalGroupMembers
                  .filter((m) => m.approvalGroupId === g.approvalGroupId)
                  .map((m) => (m.memberType === "Role" ? `role:${m.roleCode}` : `user:${m.userId}`))
                  .join(", ")}
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          groupMutation.mutate();
        }}
        style={{ marginTop: 12, display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8, alignItems: "end" }}
      >
        <label>
          Code
          <input value={groupCode} onChange={(e) => setGroupCode(e.target.value)} required />
        </label>
        <label>
          Name
          <input value={groupName} onChange={(e) => setGroupName(e.target.value)} required />
        </label>
        <button className="primary" type="submit" disabled={groupMutation.isPending}>
          Add Group
        </button>
      </form>

      <h4 style={{ marginTop: 20 }}>Add Member</h4>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          memberMutation.mutate();
        }}
        style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8, alignItems: "end" }}
      >
        <label>
          Group
          <select value={memberGroupId} onChange={(e) => setMemberGroupId(e.target.value)} required>
            <option value="">Select...</option>
            {approvalGroups.map((g) => (
              <option key={g.approvalGroupId} value={g.approvalGroupId}>
                {g.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Member Type
          <select value={memberType} onChange={(e) => setMemberType(e.target.value)}>
            <option value="Role">Role</option>
            <option value="User">User</option>
          </select>
        </label>
        {memberType === "Role" ? (
          <label>
            Role Code
            <input value={memberRoleCode} onChange={(e) => setMemberRoleCode(e.target.value)} required />
          </label>
        ) : (
          <label>
            User Id (GUID)
            <input value={memberUserId} onChange={(e) => setMemberUserId(e.target.value)} required />
          </label>
        )}
        <button className="primary" type="submit" disabled={memberMutation.isPending}>
          Add Member
        </button>
      </form>
    </div>
  );
}
