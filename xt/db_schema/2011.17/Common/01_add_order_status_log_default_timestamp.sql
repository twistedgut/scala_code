-- Add a default value to public.order_status_log.date
BEGIN;
    ALTER TABLE public.order_status_log ALTER COLUMN date SET DEFAULT now();
COMMIT;
