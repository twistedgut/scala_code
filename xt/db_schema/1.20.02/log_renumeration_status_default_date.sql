-- Add a default now() date

BEGIN;
    ALTER TABLE renumeration_status_log
        ALTER COLUMN date
            SET default now()
    ;
COMMIT;
