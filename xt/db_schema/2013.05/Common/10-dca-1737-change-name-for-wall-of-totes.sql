BEGIN;

-- See http://jira4.nap/browse/DCA-1737
-- "Pick scheduler parameters - change name for wall of totes and ordering on system parameters page"

UPDATE system_config.parameter SET description = 'Staging Area Size' WHERE name = 'wall_of_totes_size';

COMMIT;
