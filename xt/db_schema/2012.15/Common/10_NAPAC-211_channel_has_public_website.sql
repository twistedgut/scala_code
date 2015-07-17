BEGIN;

-- has_public_website is a boolean to indicate if we have a webapp to receive
-- data

ALTER TABLE public.channel ADD COLUMN
    has_public_website BOOLEAN DEFAULT FALSE NOT NULL;

COMMIT;
