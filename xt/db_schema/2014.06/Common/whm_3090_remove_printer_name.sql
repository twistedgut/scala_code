-- WHM-3090 Remove printer name column

BEGIN;
    ALTER TABLE printer.printer DROP COLUMN IF EXISTS name;
COMMIT;
