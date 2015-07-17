-- Add a default now() date

BEGIN;
    ALTER TABLE return_status_log
        ALTER COLUMN date
            SET default now()
    ;
COMMIT;
