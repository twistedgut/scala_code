-- Add a default now() date

BEGIN;
    ALTER TABLE shipment_status_log
        ALTER COLUMN date
            SET default now()
    ;
COMMIT;
