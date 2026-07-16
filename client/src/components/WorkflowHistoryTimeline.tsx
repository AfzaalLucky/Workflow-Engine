import type { ApprovalActionEntry } from "../api/types";

// Generic, business-process-agnostic: renders whatever ApprovalAction rows
// the engine returns, regardless of which workflow definition produced
// them. Works the same for Purchase Request, Leave Approval, or anything
// else configured through the admin designer.
export function WorkflowHistoryTimeline({ entries }: { entries: ApprovalActionEntry[] }) {
  if (entries.length === 0) return <p>No history yet.</p>;

  return (
    <ul className="timeline">
      {entries.map((entry) => (
        <li key={entry.approvalActionId}>
          <div>
            <strong>{entry.actionType}</strong>
            {entry.oldStageName && entry.newStageName && entry.oldStageName !== entry.newStageName && (
              <span>
                {" "}
                &middot; {entry.oldStageName} &rarr; {entry.newStageName}
              </span>
            )}
            {!entry.oldStageName && entry.newStageName && <span> &middot; entered {entry.newStageName}</span>}
          </div>
          <div className="timeline-meta">
            {entry.actorDisplayName ?? entry.actorUserId} &middot; {new Date(entry.actionAt).toLocaleString()}
          </div>
          {entry.comments && <div>&ldquo;{entry.comments}&rdquo;</div>}
        </li>
      ))}
    </ul>
  );
}
