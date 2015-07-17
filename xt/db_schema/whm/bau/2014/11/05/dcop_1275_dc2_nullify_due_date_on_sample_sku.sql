-- DCOP-1275
-- Set return due date to null for one sku in a sample cart

BEGIN;

update sample_request_det
set date_return_due = NULL
where sample_request_id = 4907 and variant_id = 3558861;

COMMIT
