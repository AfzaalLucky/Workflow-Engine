import { useQuery } from "@tanstack/react-query";
import { Link } from "react-router-dom";
import { api } from "../api/apiClient";

function summarizeContext(contextDataJson: string | null): string {
  if (!contextDataJson) return "";
  try {
    const data = JSON.parse(contextDataJson) as Record<string, unknown>;
    return Object.entries(data)
      .map(([key, value]) => `${key}: ${value}`)
      .join(", ");
  } catch {
    return "";
  }
}

export function TasksInboxPage() {
  const { data: tasks, isLoading, error } = useQuery({
    queryKey: ["myTasks"],
    queryFn: api.getMyTasks,
  });

  if (isLoading) return <p>Loading tasks...</p>;
  if (error) return <p className="form-error">Failed to load tasks.</p>;

  return (
    <div>
      <h1>My Tasks</h1>
      {tasks && tasks.length === 0 && <p>Nothing pending. You're all caught up.</p>}
      {tasks && tasks.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>Workflow</th>
              <th>Stage</th>
              <th>Business Entity</th>
              <th>Context</th>
              <th>Created</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {tasks.map((task) => (
              <tr key={task.approvalTaskId}>
                <td>{task.workflowDefinitionName}</td>
                <td>{task.stageName}</td>
                <td>
                  {task.businessEntityType} #{task.businessEntityId}
                </td>
                <td>{summarizeContext(task.contextDataJson)}</td>
                <td>{new Date(task.createdAt).toLocaleString()}</td>
                <td>
                  <Link to={`/tasks/${task.approvalTaskId}`}>Review</Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
