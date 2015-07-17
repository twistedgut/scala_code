-- Add a default 0 quantity to the quantity table
BEGIN;
    ALTER TABLE public.quantity ALTER COLUMN quantity SET DEFAULT 0;
COMMIT;
