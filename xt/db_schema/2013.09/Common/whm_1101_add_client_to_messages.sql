
-- WHM-1101 : Add client to messages. We need a less fragile way to get the client specific
--  data from warehouse common constants

BEGIN;

ALTER TABLE public.client ADD COLUMN token_name TEXT;

UPDATE public.client SET token_name = 'NAP' WHERE prl_name = 'NAP';
UPDATE public.client SET token_name = 'JC' WHERE prl_name = 'CHO';

ALTER TABLE public.client ALTER COLUMN token_name SET NOT NULL;
ALTER TABLE public.client ADD CONSTRAINT unique_token_name UNIQUE (token_name);

COMMIT;
