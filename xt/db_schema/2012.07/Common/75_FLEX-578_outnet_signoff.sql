BEGIN;


UPDATE channel_branding SET value = 'theOutnet.com' WHERE
    branding_id IN (
        SELECT id FROM branding WHERE code IN (
            'PF_NAME', 'DOC_HEADING'
        )
    ) AND
    channel_id = (SELECT id FROM channel WHERE web_name ilike 'OUTNET-%');




COMMIT;

