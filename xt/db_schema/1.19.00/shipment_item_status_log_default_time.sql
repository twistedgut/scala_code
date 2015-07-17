-- Begin set the default value for the date to current

BEGIN;
    ALTER TABLE shipment_item_status_log 
        ALTER COLUMN date SET DEFAULT current_timestamp;
COMMIT;
