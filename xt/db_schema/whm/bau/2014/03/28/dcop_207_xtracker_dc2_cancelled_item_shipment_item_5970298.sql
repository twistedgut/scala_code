BEGIN;

    -- Allow shipment-item to be 'recancelled' after it was erroniously reactivated
    DELETE FROM cancelled_item WHERE shipment_item_id = 5970298;

COMMIT;
