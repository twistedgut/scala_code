-- Add index on delivery_action_id column from log_delivery table to improve search by this column

BEGIN;
    CREATE INDEX log_delivery_action_id_idx ON log_delivery(delivery_action_id);
COMMIT;
