BEGIN;

update shipment_item set shipment_item_status_id = 5 -- Dispatched
where id = 665276;

update return_item set return_item_status_id = 9 -- Cancelled
where shipment_item_id = (
    select id from shipment_item where id = 665276
);

update return set return_status_id = 4 -- Cancelled
where id = (
    select return_id from return_item where shipment_item_id = (
        select id from shipment_item where id = 665276
    )
);


COMMIT;
