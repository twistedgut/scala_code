-- Add an index to help us search by log_delivery(date)

BEGIN;
    CREATE INDEX ON log_delivery(date);
COMMIT;
