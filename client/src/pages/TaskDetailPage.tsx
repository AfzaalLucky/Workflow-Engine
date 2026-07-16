import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { api } from "../api/apiClient";

function formatContext(contextDataJson: string | null): [string, unknown][] {
  if (!contextDataJson) return [];
  try {
    return Object.entries(JSON.parse(contextDataJson) as Record<string, unknown>);
  } catch {
    return [];
  }
}

export function TaskDetailPage() {
  const { taskId } = useParams<{ taskId: string }>();
  const approvalTaskId = Number(taskId);
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const [comments, setComments] = useState("");
  const [returnToStageId, setReturnToStageId] = useState<number | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const { data: detail, isLoading, error } = useQuery({
    queryKey: ["taskDetail", approvalTaskId],
    queryFn: () => api.getTaskDetail(approvalTaskId),
  });

  const afterAction = () => {
    queryClient.invalidateQueries({ queryKey: ["myTasks"] });
    navigate("/tasks");
  };

  const approveMutation = useMutation({
    mutationFn: () => api.approveTask(approvalTaskId, comments),
    onSuccess: afterAction,
    onError: () => setActionError("Failed to approve task."),
  });
  const rejectMutation = useMutation({
    mutationFn: () => api.rejectTask(approvalTaskId, comments),
    onSuccess: afterAction,
    onError: () => setActionError("Failed to reject task."),
  });
  const returnMutation = useMutation({
    mutationFn: () => api.returnTask(approvalTaskId, comments, returnToStageId),
    onSuccess: afterAction,
    onError: () => setActionError("Failed to return task. A comment may be required."),
  });

  if (isLoading) return <p>Loading task...</p>;
  if (error || !detail) return <p className="form-error">Task not found.</p>;

  const { task, returnOptions } = detail;
  const busy = approveMutation.isPending || rejectMutation.isPending || returnMutation.isPending;

  return (
    <div>
      <p>
        <Link to="/tasks">&larr; Back to My Tasks</Link>
      </p>
      <h1>{task.stageName}</h1>
      <div className="card">
        <p>
          <strong>Workflow:</strong> {task.workflowDefinitionName}
        </p>
        <p>
          <strong>Business Entity:</strong> {task.businessEntityType} #{task.businessEntityId}
        </p>
        <p>
          <strong>Details:</strong>
        </p>
        <ul>
          {formatContext(task.contextDataJson).map(([key, value]) => (
            <li key={key}>
              {key}: {String(value)}
            </li>
          ))}
        </ul>
      </div>

      <label>
        Comments
        <textarea rows={3} value={comments} onChange={(e) => setComments(e.target.value)} />
      </label>

      {returnOptions.length > 0 && (
        <label>
          Return to (if returning)
          <select
            value={returnToStageId ?? ""}
            onChange={(e) => setReturnToStageId(e.target.value ? Number(e.target.value) : null)}
          >
            <option value="">Default return target</option>
            {returnOptions.map((option) => (
              <option key={option.toStageId} value={option.toStageId}>
                {option.toStageName}
              </option>
            ))}
          </select>
        </label>
      )}

      {actionError && <p className="form-error">{actionError}</p>}

      <div className="action-bar">
        <button className="primary" disabled={busy} onClick={() => approveMutation.mutate()}>
          Approve
        </button>
        <button className="danger" disabled={busy} onClick={() => rejectMutation.mutate()}>
          Reject
        </button>
        {returnOptions.length > 0 && (
          <button disabled={busy} onClick={() => returnMutation.mutate()}>
            Return
          </button>
        )}
      </div>
    </div>
  );
}
