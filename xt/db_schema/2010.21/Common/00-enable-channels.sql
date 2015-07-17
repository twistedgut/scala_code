BEGIN;


ALTER TABLE public.channel ADD COLUMN is_enabled BOOLEAN DEFAULT FALSE NOT NULL;

UPDATE public.channel SET is_enabled = TRUE;

COMMIT;
