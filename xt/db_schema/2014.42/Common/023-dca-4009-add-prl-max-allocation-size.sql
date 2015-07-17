BEGIN;

ALTER TABLE prl
    ADD COLUMN max_allocation_items INTEGER;

COMMENT ON COLUMN prl.max_allocation_items IS
    'The maximum number of allocation_items allowed per allocation for this PRL. If a shipment contains more than this number of items from the PRL, multiple allocations will be created. Null value means there is no limit.';

COMMIT;
