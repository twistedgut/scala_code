-- Add a unique constraint to currency(currency)
BEGIN;
    ALTER TABLE public.currency ADD UNIQUE (currency); 
COMMIT;
