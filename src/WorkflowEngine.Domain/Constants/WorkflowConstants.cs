namespace WorkflowEngine.Domain.Constants;

// Mirrors the CHECK constraint values in the wf_* schema exactly -- these
// are stored as plain strings in SQL Server, not native enums, so the two
// must be kept in sync by hand.

public static class StageTypes
{
    public const string Start = "Start";
    public const string Approval = "Approval";
    public const string ParallelGroup = "ParallelGroup";
    public const string End = "End";
}

public static class ApproverTypes
{
    public const string User = "User";
    public const string Role = "Role";
    public const string Group = "Group";
}

public static class JoinTypes
{
    public const string All = "All";
    public const string AnyOne = "AnyOne";
    public const string AnyN = "AnyN";
}

public static class WorkflowVersionStatuses
{
    public const string Draft = "Draft";
    public const string Published = "Published";
    public const string Retired = "Retired";
}

public static class InstanceStatuses
{
    public const string InProgress = "InProgress";
    public const string Approved = "Approved";
    public const string Rejected = "Rejected";
    public const string Returned = "Returned";
    public const string Completed = "Completed";
    public const string Cancelled = "Cancelled";
    public const string Errored = "Errored";
}

public static class ApprovalTaskStatuses
{
    public const string Pending = "Pending";
    public const string Approved = "Approved";
    public const string Rejected = "Rejected";
    public const string Returned = "Returned";
    public const string Cancelled = "Cancelled";
}

public static class TaskActions
{
    public const string Approve = "Approve";
    public const string Reject = "Reject";
    public const string Return = "Return";
}
