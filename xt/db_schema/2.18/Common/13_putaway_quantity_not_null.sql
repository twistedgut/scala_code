-- Add a NOT NULL constraint to public.putaway(quantity)

BEGIN;
    ALTER TABLE public.putaway ALTER COLUMN quantity SET NOT NULL;
COMMIT;
