BEGIN;


UPDATE channel_branding SET value = 'THE OUTNET' WHERE
    branding_id = (SELECT id FROM branding WHERE code = 'PLAIN_NAME') AND
    channel_id = (SELECT id FROM channel WHERE web_name ilike 'OUTNET-%');

UPDATE channel_branding SET value = 'THE OUTNET Premier' WHERE
    branding_id = (SELECT id FROM branding WHERE code = 'PREM_NAME') AND
    channel_id = (SELECT id FROM channel WHERE web_name ilike 'OUTNET-%');


COMMIT;
