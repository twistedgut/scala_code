-- Remove reservation_consistency(adjusted) column

BEGIN;
    ALTER TABLE reservation_consistency DROP COLUMN adjusted;
COMMIT;
