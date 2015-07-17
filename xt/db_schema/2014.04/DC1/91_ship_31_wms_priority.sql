BEGIN;

    -- Update wms_priority values
    DELETE FROM sos.wms_priority;

    INSERT INTO sos.wms_priority (shipment_class_id, wms_priority, wms_bumped_priority, bumped_interval) VALUES
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD'), 20, 15, '00:00:00' ),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER'), 20, 3, '02:00:00' ),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'STAFF'), 20, NULL, NULL ),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'TRANSFER'), 20, NULL, NULL ),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'EMAIL'), 20, NULL, NULL );

    INSERT INTO sos.wms_priority (country_id, wms_priority, wms_bumped_priority, bumped_interval) VALUES
        ( (SELECT id FROM sos.country WHERE api_code = 'AU'), 20, 9, '01:00:00' ),
        ( (SELECT id FROM sos.country WHERE api_code = 'AR'), 20, 9, '01:00:00' ),
        ( (SELECT id FROM sos.country WHERE api_code = 'BH'), 20, 9, '01:00:00' ),
        ( (SELECT id FROM sos.country WHERE api_code = 'NG'), 20, 9, '01:00:00' ),
        ( (SELECT id FROM sos.country WHERE api_code = 'ZA'), 20, 9, '01:00:00' ),
        ( (SELECT id FROM sos.country WHERE api_code = 'AE'), 20, 9, '01:00:00' );

    INSERT INTO sos.wms_priority (shipment_class_attribute_id, wms_priority, wms_bumped_priority, bumped_interval) VALUES
        ( (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Nominated Day'), 20, 6, '02:00:00' ),
        ( (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Express'), 20, 12, '00:00:00' );

COMMIT;