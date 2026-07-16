Workflow Rules


Commission created → Status 1 (Initiated).
Approve from 1 → 20 (Under Leasing Approval).
Approve from 20 → 23 (Under Approval from Finance and CC).
Status 23 fans out into two parallel approval branches: Finance (Status 4) and CC (Status 19). Both must independently approve before the workflow can advance — this is a parallel gate, not a simple linear FK on LeasingCommission.StatusID.
Once both Status 4 and Status 19 are approved → 5 (Under Audit Approval).
Approve from 5 → 6 (Finance Clearance).
Approve from 6 → 7 (Cleared) — terminal/success state.
Return logic (the hard part): Any status can be "returned" to a designated prior stage (e.g., Audit Status 5 returned → Status 14 "Return from Audit" → lands back on Leasing Status 20). When that prior stage is re-approved, the record must resume to the exact stage it was returned from (Audit 5), not simply continue the normal forward path (which would otherwise go 20 → 23). This requires the schema to remember where a return came from per commission instance, since the same "return-to" status (e.g., 20) can be a resume target for returns originating from different downstream stages.