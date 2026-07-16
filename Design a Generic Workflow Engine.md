Design a Generic Workflow Engine

Act as a Senior Database Architect and Solution Architect.

Design a generic, reusable, configuration-driven workflow engine that can be integrated into any enterprise application, not just a specific module.

Technology Stack
Microsoft SQL Server
.NET Core Web API
React TypeScript

The solution must be highly scalable, extensible, and database-driven so that new workflows can be created without changing application code.

Objective

Design a workflow engine capable of handling:

Sequential approvals
Parallel approvals
Single approver
Multiple approvers
Approval groups
Return/Rework
Resume workflow
Dynamic routing
Complete approval history
Audit trail
Future workflow expansion

The workflow engine should support any business process such as:

Leasing
HR
Procurement
Finance
Purchase Requests
Claims
Document Approval
Contract Approval
Leave Approval

without requiring schema changes.

Core Requirements

The engine must be completely metadata/configuration driven.

The workflow definition should not be hardcoded.

Every workflow should define:

Stages
Transitions
Approval rules
Return rules
Parallel groups
Resume behavior