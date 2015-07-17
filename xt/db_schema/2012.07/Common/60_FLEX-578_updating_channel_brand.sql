BEGIN;

UPDATE channel_branding SET value = 'theOutnet.com' WHERE
    branding_id IN (
        SELECT id FROM branding WHERE code IN (
            'PF_NAME', 'DOC_HEADING'
        )
    ) AND
    channel_id = (SELECT id FROM channel WHERE web_name ilike 'OUTNET-%');

UPDATE channel_branding SET value = 'Kind regards' WHERE
    branding_id = (SELECT id FROM branding WHERE code = 'EMAIL_SIGNOFF') AND
    channel_id = (SELECT id FROM channel WHERE web_name ilike 'OUTNET-%');

UPDATE channel_branding SET value = 'theOutnet' WHERE
    branding_id = (SELECT id FROM branding WHERE code = 'PLAIN_NAME') AND
    channel_id = (SELECT id FROM channel WHERE web_name ilike 'OUTNET-%');

UPDATE channel_branding SET value = 'theOutnet.com Premier' WHERE
    branding_id = (SELECT id FROM branding WHERE code = 'PREM_NAME') AND
    channel_id = (SELECT id FROM channel WHERE web_name ilike 'OUTNET-%');

INSERT INTO channel_branding (
    channel_id, branding_id, value
) VALUES (
    (SELECT id FROM channel WHERE web_name ilike 'OUTNET-%'),
    (SELECT id from branding WHERE code = 'EMAIL_SIGNOFF'),
    'Kind regards'
);


COMMIT;
