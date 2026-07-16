import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "../../api/apiClient";
import type { Stage, Transition } from "../../api/types";

export function TransitionsEditor({
  workflowVersionId,
  stages,
  transitions,
}: {
  workflowVersionId: number;
  stages: Stage[];
  transitions: Transition[];
}) {
  const queryClient = useQueryClient();
  const [fromStageId, setFromStageId] = useState("");
  const [toStageId, setToStageId] = useState("");
  const [conditionExpression, setConditionExpression] = useState("");
  const [priority, setPriority] = useState("100");
  const [isDefault, setIsDefault] = useState(false);

  const stageName = (id: number) => stages.find((s) => s.stageId === id)?.name ?? id;

  const mutation = useMutation({
    mutationFn: () =>
      api.admin.upsertTransition(workflowVersionId, {
        fromStageId: Number(fromStageId),
        toStageId: Number(toStageId),
        conditionExpression: conditionExpression || null,
        priority: Number(priority),
        isDefault,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["adminVersionDetail", workflowVersionId] });
      setConditionExpression("");
    },
  });

  return (
    <div className="card">
      <h3>Transitions</h3>
      <table>
        <thead>
          <tr>
            <th>From</th>
            <th>To</th>
            <th>Condition</th>
            <th>Priority</th>
            <th>Default</th>
          </tr>
        </thead>
        <tbody>
          {transitions.map((t) => (
            <tr key={t.transitionId}>
              <td>{stageName(t.fromStageId)}</td>
              <td>{stageName(t.toStageId)}</td>
              <td>{t.conditionExpression ?? ""}</td>
              <td>{t.priority}</td>
              <td>{t.isDefault ? "Yes" : ""}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          mutation.mutate();
        }}
        style={{ marginTop: 12, display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8, alignItems: "end" }}
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
        <label>
          Priority
          <input type="number" value={priority} onChange={(e) => setPriority(e.target.value)} required />
        </label>
        <label style={{ gridColumn: "span 2" }}>
          Condition Expression (blank for default/unconditional)
          <input
            value={conditionExpression}
            onChange={(e) => setConditionExpression(e.target.value)}
            placeholder='e.g. Amount > 50000'
          />
        </label>
        <label style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
          <input type="checkbox" checked={isDefault} onChange={(e) => setIsDefault(e.target.checked)} /> Is default
        </label>
        <button className="primary" type="submit" disabled={mutation.isPending}>
          Add / Update Transition
        </button>
      </form>
    </div>
  );
}
