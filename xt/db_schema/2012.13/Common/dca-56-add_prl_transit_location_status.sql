BEGIN;

INSERT INTO flow.status ( name, type_id, is_initial )
VALUES (
    'In transit from PRL',
    (SELECT id FROM flow.type WHERE name = 'Stock Status'),
    true
);

INSERT INTO location_allowed_status ( location_id, status_id )
VALUES (
    (SELECT id FROM location WHERE location = 'Transit'),
    (SELECT id FROM flow.status WHERE name = 'In transit from PRL')
);

COMMIT;
