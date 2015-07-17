BEGIN;

-- this matches the PRL config section's "location" field (in XT)
INSERT INTO location (location) VALUES ('Full PRL');

INSERT INTO location_allowed_status (location_id, status_id)
VALUES (
    ( SELECT id FROM location WHERE location = 'Full PRL'),
    ( SELECT id FROM flow.status WHERE name = 'Main Stock')
),
(
    ( SELECT id FROM location WHERE location = 'Full PRL'),
    ( SELECT id FROM flow.status WHERE name = 'Dead Stock')
);

COMMIT;
