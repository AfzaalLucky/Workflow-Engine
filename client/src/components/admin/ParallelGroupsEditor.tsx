import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { api } from "../../api/apiClient";
import type { ParallelGroup } from "../../api/types";

const JOIN_TYPES = ["All", "AnyOne", "AnyN"];

export function ParallelGroupsEditor({
  workflowVersionId,
  parallelGroups,
}: {
  workflowVersionId: number;
  parallelGroups: ParallelGroup[];
}) {
  const queryClient = useQueryClient();
  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [joinType, setJoinType] = useState("All");
  const [minRequiredApprovals, setMinRequiredApprovals] = useState("");

  const mutation = useMutation({
    mutationFn: () =>
      api.admin.upsertParallelGroup(workflowVersionId, {
        code,
        name,
        joinType,
        minRequiredApprovals: minRequiredApprovals ? Number(minRequiredApprovals) : null,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["adminVersionDetail", workflowVersionId] });
      setCode("");
      setName("");
    },
  });

  return (
    <div className="card">
      <h3>Parallel Groups</h3>
      <table>
        <thead>
          <tr>
            <th>Code</th>
            <th>Name</th>
            <th>Join Type</th>
            <th>Min Required</th>
          </tr>
        </thead>
        <tbody>
          {parallelGroups.map((g) => (
            <tr key={g.parallelGroupId}>
              <td>{g.code}</td>
              <td>{g.name}</td>
              <td>{g.joinType}</td>
              <td>{g.minRequiredApprovals ?? ""}</td>
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
          Code
          <input value={code} onChange={(e) => setCode(e.target.value)} required />
        </label>
        <label>
          Name
          <input value={name} onChange={(e) => setName(e.target.value)} required />
        </label>
        <label>
          Join Type
          <select value={joinType} onChange={(e) => setJoinType(e.target.value)}>
            {JOIN_TYPES.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
        </label>
        <label>
          Min Required (AnyN)
          <input
            type="number"
            value={minRequiredApprovals}
            onChange={(e) => setMinRequiredApprovals(e.target.value)}
          />
        </label>
        <button className="primary" type="submit" disabled={mutation.isPending}>
          Add / Update Group
        </button>
      </form>
    </div>
  );
}
