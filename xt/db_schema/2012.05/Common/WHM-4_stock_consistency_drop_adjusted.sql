-- Drop unnecessary 'adjusted' column

BEGIN;
    ALTER TABLE stock_consistency DROP COLUMN adjusted;
COMMIT;
