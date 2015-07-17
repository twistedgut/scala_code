-- CANDO-2676: Add Renumeration Reason FK to 'bulk_reimbursement' table

BEGIN WORK;

ALTER TABLE bulk_reimbursement
    ADD COLUMN renumeration_reason_id INTEGER REFERENCES renumeration_reason(id)
;

COMMIT WORK;
