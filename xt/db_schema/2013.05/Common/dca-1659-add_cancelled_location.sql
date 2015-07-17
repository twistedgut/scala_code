
-- DCA-1659: Add Location for "Cancelled - to Putaway" (typically from
-- Packing Exception)

BEGIN;

INSERT INTO flow.status (name, type_id, is_initial)
    VALUES ('In transit to PRL', 1, 't');


INSERT INTO location (location)
    VALUES ('Cancelled-to-Putaway');
INSERT INTO location_allowed_status (location_id, status_id)
    VALUES (
        (SELECT id from location    where location = 'Cancelled-to-Putaway'),
        (SELECT id from flow.status where name     = 'In transit to PRL'   )
    );

COMMIT;

