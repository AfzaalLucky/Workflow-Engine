import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "../api/apiClient";
import { ApprovalGroupsEditor } from "../components/admin/ApprovalGroupsEditor";
import { ApprovalRulesEditor } from "../components/admin/ApprovalRulesEditor";
import { ParallelGroupsEditor } from "../components/admin/ParallelGroupsEditor";
import { ReturnRulesEditor } from "../components/admin/ReturnRulesEditor";
import { StagesEditor } from "../components/admin/StagesEditor";
import { TransitionsEditor } from "../components/admin/TransitionsEditor";

// Proof of genericness: any business process -- Purchase Request, Leave
// Approval, Contract Approval, whatever -- is authored entirely through
// these screens. No code or wf_* schema changes are ever required.
export function AdminWorkflowsPage() {
  const queryClient = useQueryClient();
  const [selectedVersionId, setSelectedVersionId] = useState<number | null>(null);

  const definitionsQuery = useQuery({
    queryKey: ["adminDefinitions"],
    queryFn: api.admin.getDefinitions,
  });

  const versionDetailQuery = useQuery({
    queryKey: ["adminVersionDetail", selectedVersionId],
    queryFn: () => api.admin.getVersionDetail(selectedVersionId!),
    enabled: selectedVersionId !== null,
  });

  const [newCode, setNewCode] = useState("");
  const [newName, setNewName] = useState("");
  const createDefinitionMutation = useMutation({
    mutationFn: () => api.admin.upsertDefinition({ code: newCode, name: newName, description: null, isActive: true }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["adminDefinitions"] });
      setNewCode("");
      setNewName("");
    },
  });

  const createVersionMutation = useMutation({
    mutationFn: (workflowDefinitionId: number) => api.admin.createVersion(workflowDefinitionId),
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ["adminDefinitions"] });
      setSelectedVersionId(result.workflowVersionId);
    },
  });

  const publishMutation = useMutation({
    mutationFn: (workflowVersionId: number) => api.admin.publishVersion(workflowVersionId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["adminDefinitions"] });
      queryClient.invalidateQueries({ queryKey: ["adminVersionDetail", selectedVersionId] });
    },
  });

  return (
    <div>
      <h1>Workflow Admin</h1>

      <div className="card">
        <h3>Workflow Definitions</h3>
        <table>
          <thead>
            <tr>
              <th>Code</th>
              <th>Name</th>
              <th>Published Version</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {definitionsQuery.data?.map((def) => (
              <tr key={def.workflowDefinitionId}>
                <td>{def.code}</td>
                <td>{def.name}</td>
                <td>{def.publishedVersionNumber ?? "(none)"}</td>
                <td>
                  <button onClick={() => createVersionMutation.mutate(def.workflowDefinitionId)}>
                    New Draft Version
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            createDefinitionMutation.mutate();
          }}
          style={{ marginTop: 12, display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8, alignItems: "end" }}
        >
          <label>
            Code
            <input value={newCode} onChange={(e) => setNewCode(e.target.value)} placeholder="LEAVE_APPROVAL" required />
          </label>
          <label>
            Name
            <input value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="Leave Approval" required />
          </label>
          <button className="primary" type="submit" disabled={createDefinitionMutation.isPending}>
            New Workflow Definition
          </button>
        </form>
      </div>

      <div className="card">
        <label>
          Editing Workflow Version Id
          <input
            type="number"
            value={selectedVersionId ?? ""}
            onChange={(e) => setSelectedVersionId(e.target.value ? Number(e.target.value) : null)}
            placeholder="Click 'New Draft Version' above, or type an id"
          />
        </label>
        {selectedVersionId !== null && (
          <button onClick={() => publishMutation.mutate(selectedVersionId)} disabled={publishMutation.isPending}>
            Publish this version
          </button>
        )}
      </div>

      {versionDetailQuery.data && (
        <>
          <p>
            Version {versionDetailQuery.data.version.versionNumber} &middot; Status:{" "}
            <span className={`badge status-${versionDetailQuery.data.version.status}`}>
              {versionDetailQuery.data.version.status}
            </span>
          </p>

          <ParallelGroupsEditor
            workflowVersionId={selectedVersionId!}
            parallelGroups={versionDetailQuery.data.parallelGroups}
          />
          <StagesEditor
            workflowVersionId={selectedVersionId!}
            stages={versionDetailQuery.data.stages}
            parallelGroups={versionDetailQuery.data.parallelGroups}
          />
          <TransitionsEditor
            workflowVersionId={selectedVersionId!}
            stages={versionDetailQuery.data.stages}
            transitions={versionDetailQuery.data.transitions}
          />
          <ApprovalGroupsEditor
            workflowVersionId={selectedVersionId!}
            approvalGroups={versionDetailQuery.data.approvalGroups}
            approvalGroupMembers={versionDetailQuery.data.approvalGroupMembers}
          />
          <ApprovalRulesEditor
            workflowVersionId={selectedVersionId!}
            stages={versionDetailQuery.data.stages}
            approvalRules={versionDetailQuery.data.approvalRules}
            approvalGroups={versionDetailQuery.data.approvalGroups}
          />
          <ReturnRulesEditor
            workflowVersionId={selectedVersionId!}
            stages={versionDetailQuery.data.stages}
            returnRules={versionDetailQuery.data.returnRules}
          />
        </>
      )}
    </div>
  );
}
