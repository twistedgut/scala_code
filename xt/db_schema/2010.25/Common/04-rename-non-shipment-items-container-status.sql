--  Rename Non-shipment Items to Superflous Items
BEGIN;

    UPDATE container_status
    SET name='Superfluous Items'
    WHERE name='Non-shipment Items'
    ;

COMMIT;
