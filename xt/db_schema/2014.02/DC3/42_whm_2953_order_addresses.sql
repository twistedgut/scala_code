-- Update addresses used by transfer shipments to point to proper countries
BEGIN;

    UPDATE order_address
    SET country = 'Hong Kong'
    WHERE id IN (
        SELECT shipment_address_id
        FROM shipment
        WHERE shipment_class_id = (SELECT id FROM shipment_class WHERE class = 'Transfer Shipment')
    )
    AND country = 'HK';

COMMIT;