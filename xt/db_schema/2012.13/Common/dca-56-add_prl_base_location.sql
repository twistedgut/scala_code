BEGIN;

INSERT INTO location ( location )
    VALUES ( 'PRL Base' )
;

INSERT INTO location_allowed_status ( location_id, status_id )
VALUES
    (
        (SELECT id FROM location WHERE location = 'PRL Base'),
        (SELECT id FROM flow.status WHERE name = 'Main Stock')
    ),
    (
        (SELECT id FROM location WHERE location = 'PRL Base'),
        (SELECT id FROM flow.status WHERE name = 'Dead Stock')
    )
;

COMMIT;
