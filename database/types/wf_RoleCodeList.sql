-- Passes a caller's JWT role claims into procs that need to check
-- role/group-based task eligibility (the engine never stores role
-- membership itself -- roles live in the JWT).
CREATE TYPE dbo.wf_RoleCodeList AS TABLE
(
    RoleCode VARCHAR(50) NOT NULL PRIMARY KEY
);
GO
