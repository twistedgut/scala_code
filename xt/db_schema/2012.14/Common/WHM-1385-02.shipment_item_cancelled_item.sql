-- Make shipment_item->cancelled_item a 1-1 relationship

BEGIN;
    -- Remove all duplicate rows (keep oldest)
    DELETE FROM cancelled_item me
    USING cancelled_item ci
    WHERE me.shipment_item_id = ci.shipment_item_id
    AND me.id > ci.id;

    -- Make this a 1-1
    ALTER TABLE cancelled_item
        ADD PRIMARY KEY (shipment_item_id),
        DROP id
    ;
COMMIT;
