-- DCA-591: Replace putaway_prep_group.stock_process_id with group_id,
--          and add a NOT NULL constraint on more putaway_prep_inventory columns

BEGIN;

ALTER TABLE putaway_prep_group DROP COLUMN stock_process_id;

TRUNCATE putaway_prep_group CASCADE;
ALTER TABLE putaway_prep_group ADD COLUMN group_id INTEGER NOT NULL;

ALTER TABLE putaway_prep_inventory ALTER COLUMN putaway_prep_container_id SET NOT NULL;
ALTER TABLE putaway_prep_inventory ALTER COLUMN putaway_prep_group_id SET NOT NULL;

COMMIT;
