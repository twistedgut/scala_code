
--
-- DCA-1050 - Clean up old unused 'PRL Base' location and associated allowed statuses.
--            This was supposed to be renamed to 'Full PRL' a while back   
--

BEGIN;

DELETE FROM location_allowed_status WHERE location_id = (SELECT id FROM location WHERE location = 'PRL Base');
DELETE FROM location WHERE location = 'PRL Base';

COMMIT;
