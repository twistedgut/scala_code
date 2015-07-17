BEGIN;

    -- Update DC2 Premier bump-interval to be more aggressive for Sale event
    UPDATE sos.wms_priority SET bumped_interval = '12:00:00' WHERE shipment_class_id IN (
        SELECT id FROM sos.shipment_class WHERE api_code IN ('PREMIER_DAYTIME', 'PREMIER_EVENING')
    );

COMMIT;