BEGIN;

    -- Remove the cancelled_item entry for a shipment-item that got picked by the
    -- pick-scheduler so it can be re-cancelled
    DELETE FROM cancelled_item WHERE shipment_item_id = 6244336;

COMMIT;