-- Deploys the full database layer in dependency order. Run with sqlcmd or
-- SSMS (SQLCMD mode) against the target database, e.g.:
--   sqlcmd -S <server> -d <database> -i database\00_deploy_all.sql
:r .\schema\01_metadata.sql
:r .\schema\02_runtime.sql
:r .\schema\03_audit.sql
:r .\types\wf_RoleCodeList.sql
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
:r .\procedures\Runtime\wf_CreateTasksForStage.sql
:r .\procedures\Runtime\wf_StartWorkflowInstance.sql
:r .\procedures\Runtime\wf_AdvanceToStage.sql
:r .\procedures\Runtime\wf_TryCompleteParallelGroup.sql
:r .\procedures\Runtime\wf_ActOnTask.sql
:r .\procedures\Runtime\wf_ResumeWorkflowInstance.sql
:r .\procedures\Query\wf_GetCandidateTransitions.sql
:r .\procedures\Query\wf_GetMyPendingTasks.sql
:r .\procedures\Query\wf_GetTaskDetail.sql
:r .\procedures\Query\wf_GetWorkflowInstanceStatus.sql
:r .\procedures\Query\wf_GetWorkflowInstanceHistory.sql
:r .\seed\seed_purchase_request_workflow.sql
:r .\seed\seed_leasing_commission_workflow.sql
:r .\business\PurchaseRequest\schema.sql
:r .\business\PurchaseRequest\procedures.sql
:r .\business\LeasingCommission\schema.sql
:r .\business\LeasingCommission\procedures.sql
