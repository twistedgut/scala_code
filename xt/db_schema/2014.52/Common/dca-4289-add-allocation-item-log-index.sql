BEGIN;

create index idx__allocation_item_log__allocation_item_id on allocation_item_log(allocation_item_id);

COMMIT;
