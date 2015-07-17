-- Add some indexes to speed up sample_request query

BEGIN;
    CREATE INDEX ON sample_request_det(date_return_due);
    CREATE INDEX ON sample_request_det(date_returned);
COMMIT;
