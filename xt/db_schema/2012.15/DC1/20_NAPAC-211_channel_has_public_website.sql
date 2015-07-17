BEGIN;

-- We have websites for all of these! Yippee!
UPDATE public.channel SET has_public_website = TRUE;

COMMIT;
