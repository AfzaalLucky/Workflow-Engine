namespace WorkflowEngine.Api.Security;

// Stand-in for a real identity provider. Backs the self-issued
// /api/auth/login endpoint with a fixed roster of demo users whose roles
// match the seeded workflows (Purchase Request and Leasing Commission).
// Swapping in a real IdP later only means replacing DemoUserStore +
// AuthController -- the JWT shape (a `sub` claim plus one or more `role`
// claims) is what the rest of the engine depends on, and that stays the same.
public record DemoUser(Guid UserId, string Username, string Password, string DisplayName, string[] Roles);

public static class DemoUserStore
{
    public static readonly IReadOnlyList<DemoUser> Users =
    [
        new(new Guid("AAAAAAAA-0000-0000-0000-000000000001"), "requester", "Requester@123!", "Rana Requester", ["Requester"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-000000000002"), "manager", "Manager@123!", "Mona Manager", ["Manager"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-000000000003"), "finance", "Finance@123!", "Farid Finance", ["FinanceApprover"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-000000000004"), "legal", "Legal@123!", "Layla Legal", ["Legal"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-000000000005"), "procurement", "Procurement@123!", "Paul Procurement", ["Procurement"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-000000000006"), "director", "Director@123!", "Dana Director", ["Director"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-000000000007"), "admin", "Admin@123!", "Adam Admin", ["WorkflowAdmin"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-000000000008"), "leasingofficer", "LeasingOfficer@123!", "Layla Leasing", ["LeasingApprover"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-000000000009"), "leasingfinance", "LeasingFinance@123!", "Feras Finance", ["LeasingFinanceApprover"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-00000000000A"), "leasingcc", "LeasingCC@123!", "Carla CC", ["LeasingCCApprover"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-00000000000B"), "auditor", "Auditor@123!", "Aaron Auditor", ["LeasingAuditor"]),
        new(new Guid("AAAAAAAA-0000-0000-0000-00000000000C"), "leasingclearance", "LeasingClearance@123!", "Cleo Clearance", ["LeasingFinanceClearanceApprover"]),
    ];

    public static DemoUser? FindByCredentials(string username, string password) =>
        Users.FirstOrDefault(u =>
            string.Equals(u.Username, username, StringComparison.OrdinalIgnoreCase) && u.Password == password);
}
