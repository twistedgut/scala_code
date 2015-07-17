-- This whitespace padding is bloody annoying

BEGIN;
    ALTER TABLE operator_preferences
        ALTER COLUMN printer_station_name TYPE text,
        ALTER COLUMN packing_station_name TYPE text,
        ALTER COLUMN packing_printer TYPE text;
COMMIT;
