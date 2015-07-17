BEGIN;

    ALTER TABLE shipment_item
        ADD COLUMN container VARCHAR(255);
    CREATE INDEX shipment_item_container_index on shipment_item(container);

    -- Add meaningless container id to any shipment items which are currently in picked state
    -- otherwise may have problems completing picks for half picked shipments
    UPDATE shipment_item set container = 'M000000' where shipment_item_status_id = 3 and container is null;

COMMIT;
