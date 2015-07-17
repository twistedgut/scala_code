BEGIN;

INSERT INTO channel (
    id, name, business_id, distrib_centre_id, web_name, is_enabled, timezone
) VALUES ( 
    8, 
    'JIMMYCHOO.COM',
    ( SELECT id FROM business WHERE name = 'JIMMYCHOO.COM' ),
    ( SELECT id FROM distrib_centre WHERE name = 'DC2' ),
    'JC-AM',
    true,
    'America/Chicago'
);

COMMIT;
