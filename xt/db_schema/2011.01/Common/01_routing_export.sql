BEGIN;

ALTER TABLE public.routing_export ADD COLUMN channel_id INTEGER;

COMMIT;
