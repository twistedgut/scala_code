BEGIN;

update fulfilment_item set inventory_id = null
where fulfilment_item_status_id = (
    select id from fulfilment_item_status where status = 'pick_failed_resolved'
)
and inventory_id is not null;

COMMIT;
