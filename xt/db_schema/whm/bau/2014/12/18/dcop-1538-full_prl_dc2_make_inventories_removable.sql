-- DCOP-1538
-- Remove migration_items from depricated schema so corresponding inventories
-- could be removed

BEGIN;

DELETE FROM deprecated.migration_item WHERE inventory_id IN (60730, 60728);

COMMIT;
