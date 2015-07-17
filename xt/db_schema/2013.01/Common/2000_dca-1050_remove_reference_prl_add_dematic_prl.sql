
--
-- DCA-1050 - Remove old "Reference PRL",
--            add new "Dematic PRL" and associated allowed types
--

BEGIN;

-- Remove "Reference PRL"
DELETE FROM location_allowed_status WHERE location_id = (SELECT id FROM location WHERE location = 'Reference PRL');
DELETE FROM location WHERE location = 'Reference PRL';

-- Add "Dematic PRL" and associated allowed types
INSERT INTO location (location) VALUES ('Dematic PRL');
INSERT INTO location_allowed_status (location_id, status_id) VALUES (
    (SELECT id FROM location WHERE location = 'Dematic PRL'),
    (SELECT id FROM flow.status WHERE name = 'Main Stock')
);
INSERT INTO location_allowed_status (location_id, status_id) VALUES (
    (SELECT id FROM location WHERE location = 'Dematic PRL'),
    (SELECT id FROM flow.status WHERE name = 'Dead Stock')
);

COMMIT;
