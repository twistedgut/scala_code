-- Add a unique constraint to pws_action(action)

BEGIN;
    ALTER TABLE pws_action ADD UNIQUE (action);
COMMIT;
