BEGIN;

-- Currently we only have NAP APAC
UPDATE public.channel SET has_public_website = TRUE WHERE
    business_id = (
        SELECT id FROM business WHERE config_section = 'NAP'
    );

COMMIT;
