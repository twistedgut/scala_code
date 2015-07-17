BEGIN;

-- See http://jira4.nap/browse/DCA-1737
-- "Pick scheduler parameters - change name for wall of totes and ordering on system parameters page"

-- Add sort_order column
ALTER TABLE system_config.parameter ADD COLUMN sort_order INT NULL;

-- Define sort order for Fulfilment/Selection parameters
UPDATE system_config.parameter SET sort_order = 1000 WHERE name = 'batch_interval';
UPDATE system_config.parameter SET sort_order = 2000 WHERE name = 'batch_size';
UPDATE system_config.parameter SET sort_order = 3000 WHERE name = 'enable_auto_selection';

-- Define sort order for PRL parameters
UPDATE system_config.parameter SET sort_order = 1000 WHERE name = 'full_prl_pool_size';
UPDATE system_config.parameter SET sort_order = 2000 WHERE name = 'wall_of_totes_size';
UPDATE system_config.parameter SET sort_order = 3000 WHERE name = 'dematic_pool_size';
UPDATE system_config.parameter SET sort_order = 4000 WHERE name = 'packing_pool_size';

-- Make sort_order column NOT NULL
ALTER TABLE system_config.parameter ALTER COLUMN sort_order SET NOT NULL;

COMMIT;
