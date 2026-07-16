import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useParams } from "react-router-dom";
import { api } from "../api/apiClient";
import { WorkflowHistoryTimeline } from "../components/WorkflowHistoryTimeline";

export function InstanceHistoryPage() {
  const { instanceId } = useParams<{ instanceId: string }>();
  const queryClient = useQueryClient();
  const [resumeError, setResumeError] = useState<string | null>(null);

  const statusQuery = useQuery({
    queryKey: ["instanceStatus", instanceId],
    queryFn: () => api.getInstanceStatus(instanceId!),
    enabled: !!instanceId,
  });

  const historyQuery = useQuery({
    queryKey: ["instanceHistory", instanceId],
    queryFn: () => api.getInstanceHistory(instanceId!),
    enabled: !!instanceId,
  });

  const resumeMutation = useMutation({
    mutationFn: () => api.resumeInstance(instanceId!, null),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["instanceStatus", instanceId] });
      queryClient.invalidateQueries({ queryKey: ["instanceHistory", instanceId] });
    },
    onError: () => setResumeError("Failed to resume this workflow instance."),
  });

  if (statusQuery.isLoading || historyQuery.isLoading) return <p>Loading...</p>;
  if (statusQuery.error || !statusQuery.data) return <p className="form-error">Instance not found.</p>;

  const { instance, pendingTasks } = statusQuery.data;

  return (
    <div>
      <h1>{instance.workflowDefinitionName}</h1>
      <div className="card">
        <p>
          <strong>Status:</strong> <span className={`badge status-${instance.status}`}>{instance.status}</span>
        </p>
        <p>
          <strong>Business Entity:</strong> {instance.businessEntityType} #{instance.businessEntityId}
        </p>
        <p>
          <strong>Current Stage:</strong> {instance.currentStageName ?? "-"}
        </p>
        {pendingTasks.length > 0 && (
          <p>
            <strong>Pending on:</strong> {pendingTasks.map((t) => t.stageName).join(", ")}
          </p>
        )}

        {instance.status === "Returned" && (
          <div className="action-bar">
            <button className="primary" disabled={resumeMutation.isPending} onClick={() => resumeMutation.mutate()}>
              Resume workflow
            </button>
          </div>
        )}
        {resumeError && <p className="form-error">{resumeError}</p>}
      </div>

      <h2>History</h2>
      <WorkflowHistoryTimeline entries={historyQuery.data ?? []} />
    </div>
  );
}
