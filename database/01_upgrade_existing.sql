-- Upgrades an EXISTING database to the generic engine. Run with sqlcmd
-- from the database folder, e.g.:
--   sqlcmd -S <server> -d WorkflowEngineDb -i 01_upgrade_existing.sql
-- Schema changes are idempotent ALTERs; every proc is CREATE OR ALTER and
-- every seed is IF NOT EXISTS-guarded, so re-running is safe.
-- (types\wf_RoleCodeList.sql is skipped: it already exists and is unchanged.)
:r .\migrations\001_generic_engine_upgrade.sql
:r .\procedures\Metadata\wf_UpsertWorkflowDefinition.sql
:r .\procedures\Metadata\wf_CreateWorkflowVersion.sql
:r .\procedures\Metadata\wf_PublishWorkflowVersion.sql
:r .\procedures\Metadata\wf_UpsertStage.sql
:r .\procedures\Metadata\wf_UpsertTransition.sql
:r .\procedures\Metadata\wf_UpsertParallelGroup.sql
:r .\procedures\Metadata\wf_UpsertApprovalGroup.sql
:r .\procedures\Metadata\wf_UpsertApprovalGroupMember.sql
:r .\procedures\Metadata\wf_UpsertApprovalRule.sql
:r .\procedures\Metadata\wf_UpsertReturnRule.sql
:r .\procedures\Metadata\wf_GetWorkflowDefinitions.sql
:r .\procedures\Metadata\wf_GetWorkflowVersionDetail.sql
:r .\procedures\Metadata\wf_UpsertUserRef.sql
:r .\procedures\Runtime\wf_EnqueueEvent.sql
:r .\procedures\Runtime\wf_CreateTasksForStage.sql
:r .\procedures\Runtime\wf_StartWorkflowInstance.sql
:r .\procedures\Runtime\wf_AdvanceToStage.sql
:r .\procedures\Runtime\wf_TryCompleteParallelGroup.sql
:r .\procedures\Runtime\wf_ActOnTask.sql
:r .\procedures\Runtime\wf_ResumeWorkflowInstance.sql
:r .\procedures\Runtime\wf_MarkInstanceErrored.sql
:r .\procedures\Events\wf_ClaimWorkflowEvents.sql
:r .\procedures\Events\wf_CompleteWorkflowEvent.sql
:r .\procedures\Query\wf_GetCandidateTransitions.sql
:r .\procedures\Query\wf_GetMyPendingTasks.sql
:r .\procedures\Query\wf_GetTaskDetail.sql
:r .\procedures\Query\wf_GetWorkflowInstanceStatus.sql
:r .\procedures\Query\wf_GetWorkflowInstanceHistory.sql
:r .\procedures\Query\wf_GetWorkflowInstances.sql
:r .\seed\seed_purchase_request_workflow.sql
:r .\seed\seed_leasing_commission_workflow.sql
:r .\business\PurchaseRequest\procedures.sql
:r .\business\LeasingCommission\procedures.sql
