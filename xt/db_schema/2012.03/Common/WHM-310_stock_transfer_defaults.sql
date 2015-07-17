-- Add a default for stock_transfer(date)

BEGIN;
    ALTER TABLE stock_transfer ALTER COLUMN date SET DEFAULT now();
COMMIT;
