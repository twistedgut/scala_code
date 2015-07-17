BEGIN;

    -- Remove an entry in the cancelled_item table as it's parent is not in 'cancelled'
    -- or 'cancel-pending' status. This prevents the order from being fully cancelled
    DELETE FROM cancelled_item where shipment_item_id = 6675427;

COMMIT;