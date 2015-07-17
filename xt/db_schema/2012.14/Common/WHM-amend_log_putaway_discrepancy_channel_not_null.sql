-- Make channel not null for log_putaway_discrepancy table

BEGIN;
    ALTER TABLE log_putaway_discrepancy
    ALTER COLUMN channel_id SET not null;
COMMIT;
