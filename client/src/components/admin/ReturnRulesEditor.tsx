import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "../../api/apiClient";
import type { ReturnRule, Stage } from "../../api/types";

export function ReturnRulesEditor({
  workflowVersionId,
  stages,
  returnRules,
}: {
  workflowVersionId: number;
  stages: Stage[];
  returnRules: ReturnRule[];
}) {
  const queryClient = useQueryClient();
  const [fromStageId, setFromStageId] = useState("");
  const [toStageId, setToStageId] = useState("");
  const [resetApprovalsOnReturn, setResetApprovalsOnReturn] = useState(true);
  const [requireComment, setRequireComment] = useState(true);

  const stageName = (id: number) => stages.find((s) => s.stageId === id)?.name ?? id;

  const mutation = useMutation({
    mutationFn: () =>
      api.admin.upsertReturnRule({
        fromStageId: Number(fromStageId),
        toStageId: Number(toStageId),
        resetApprovalsOnReturn,
        requireComment,
      }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["adminVersionDetail", workflowVersionId] }),
  });

  return (
    <div className="card">
      <h3>Return Rules</h3>
      <table>
        <thead>
          <tr>
            <th>From</th>
            <th>To</th>
            <th>Reset Approvals</th>
            <th>Require Comment</th>
          </tr>
        </thead>
        <tbody>
          {returnRules.map((r) => (
            <tr key={r.returnRuleId}>
              <td>{stageName(r.fromStageId)}</td>
              <td>{r.toStageName ?? stageName(r.toStageId)}</td>
              <td>{r.resetApprovalsOnReturn ? "Yes" : "No"}</td>
              <td>{r.requireComment ? "Yes" : "No"}</td>
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
          From Stage
          <select value={fromStageId} onChange={(e) => setFromStageId(e.target.value)} required>
            <option value="">Select...</option>
            {stages.map((s) => (
              <option key={s.stageId} value={s.stageId}>
                {s.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          To Stage
          <select value={toStageId} onChange={(e) => setToStageId(e.target.value)} required>
            <option value="">Select...</option>
            {stages.map((s) => (
              <option key={s.stageId} value={s.stageId}>
                {s.name}
              </option>
            ))}
          </select>
        </label>
        <label style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
          <input
            type="checkbox"
            checked={resetApprovalsOnReturn}
            onChange={(e) => setResetApprovalsOnReturn(e.target.checked)}
          />{" "}
          Reset approvals
        </label>
        <label style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
          <input type="checkbox" checked={requireComment} onChange={(e) => setRequireComment(e.target.checked)} />{" "}
          Require comment
        </label>
        <button className="primary" type="submit" disabled={mutation.isPending}>
          Add / Update Return Rule
        </button>
      </form>
    </div>
  );
}
