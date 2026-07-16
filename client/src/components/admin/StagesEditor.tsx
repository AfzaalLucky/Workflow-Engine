import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "../../api/apiClient";
import type { ParallelGroup, Stage } from "../../api/types";

const STAGE_TYPES = ["Start", "Approval", "ParallelGroup", "End"];

export function StagesEditor({
  workflowVersionId,
  stages,
  parallelGroups,
}: {
  workflowVersionId: number;
  stages: Stage[];
  parallelGroups: ParallelGroup[];
}) {
  const queryClient = useQueryClient();
  const [stageKey, setStageKey] = useState("");
  const [name, setName] = useState("");
  const [stageOrder, setStageOrder] = useState("10");
  const [stageType, setStageType] = useState("Approval");
  const [parallelGroupId, setParallelGroupId] = useState("");
  const [isInitial, setIsInitial] = useState(false);
  const [isFinal, setIsFinal] = useState(false);

  const mutation = useMutation({
    mutationFn: () =>
      api.admin.upsertStage(workflowVersionId, {
        stageKey,
        name,
        stageOrder: Number(stageOrder),
        stageType,
        parallelGroupId: parallelGroupId ? Number(parallelGroupId) : null,
        isInitial,
        isFinal,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["adminVersionDetail", workflowVersionId] });
      setStageKey("");
      setName("");
    },
  });

  return (
    <div className="card">
      <h3>Stages</h3>
      <table>
        <thead>
          <tr>
            <th>Order</th>
            <th>Key</th>
            <th>Name</th>
            <th>Type</th>
            <th>Parallel Group</th>
            <th>Initial</th>
            <th>Final</th>
          </tr>
        </thead>
        <tbody>
          {stages.map((stage) => (
            <tr key={stage.stageId}>
              <td>{stage.stageOrder}</td>
              <td>{stage.stageKey}</td>
              <td>{stage.name}</td>
              <td>{stage.stageType}</td>
              <td>{parallelGroups.find((g) => g.parallelGroupId === stage.parallelGroupId)?.name ?? ""}</td>
              <td>{stage.isInitial ? "Yes" : ""}</td>
              <td>{stage.isFinal ? "Yes" : ""}</td>
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
          Key
          <input value={stageKey} onChange={(e) => setStageKey(e.target.value)} required />
        </label>
        <label>
          Name
          <input value={name} onChange={(e) => setName(e.target.value)} required />
        </label>
        <label>
          Order
          <input type="number" value={stageOrder} onChange={(e) => setStageOrder(e.target.value)} required />
        </label>
        <label>
          Type
          <select value={stageType} onChange={(e) => setStageType(e.target.value)}>
            {STAGE_TYPES.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </label>
        <label>
          Parallel Group
          <select value={parallelGroupId} onChange={(e) => setParallelGroupId(e.target.value)}>
            <option value="">(none)</option>
            {parallelGroups.map((g) => (
              <option key={g.parallelGroupId} value={g.parallelGroupId}>
                {g.name}
              </option>
            ))}
          </select>
        </label>
        <label style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
          <input type="checkbox" checked={isInitial} onChange={(e) => setIsInitial(e.target.checked)} /> Initial
        </label>
        <label style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
          <input type="checkbox" checked={isFinal} onChange={(e) => setIsFinal(e.target.checked)} /> Final
        </label>
        <button className="primary" type="submit" disabled={mutation.isPending}>
          Add / Update Stage
        </button>
      </form>
    </div>
  );
}
