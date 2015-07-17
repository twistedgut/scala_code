-- Add a default value timestamp to shipment date col

BEGIN;
    ALTER TABLE public.shipment ALTER COLUMN date SET DEFAULT now();
COMMIT;
