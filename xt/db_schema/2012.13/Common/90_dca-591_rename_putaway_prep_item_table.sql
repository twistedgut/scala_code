-- DCA-591: rename putaway_prep_item table to putaway_prep_inventory
--          because it has a quantity column like the main inventory table
--      and add a foreign key to putaway_process_group.id
--      and make several more modifications

BEGIN;

ALTER TABLE putaway_prep_item RENAME TO putaway_prep_inventory;

ALTER TABLE putaway_prep_inventory ADD COLUMN putaway_prep_group_id INTEGER REFERENCES putaway_prep_group(id) DEFERRABLE;

ALTER TABLE putaway_prep_inventory RENAME COLUMN putaway_prep_id TO putaway_prep_container_id;

COMMIT;
