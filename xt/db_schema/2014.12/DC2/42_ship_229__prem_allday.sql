BEGIN;

    -- Add data for the Premier All-Day shipment-class
    -- Even though this is being created for the sole benefit of Jimmy Choo, we'll keep
    -- the settings (and overrides etc) consistent with the other Premier shipment-classes
    -- so that we can easily use it for other shipments if we want to
    INSERT INTO sos.processing_time (class_id, processing_time)
        VALUES (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_ALL_DAY'),
            '01:45:00'
        );

    INSERT INTO sos.processing_time_override (major_id, minor_id)
        VALUES (
            (
                SELECT id FROM sos.processing_time
                    WHERE class_id = (
                        SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_ALL_DAY'
                    )
            ),
            (
                SELECT id FROM sos.processing_time
                    WHERE channel_id = (
                        SELECT id FROM sos.channel WHERE api_code = 'TON'
                    )
            )
        );

    INSERT INTO sos.wms_priority (shipment_class_id, wms_priority, wms_bumped_priority, bumped_interval)
        VALUES (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_ALL_DAY'),
            20,
            3,
            '12:00:00'
        );

    INSERT INTO sos.truck_departure__class (shipment_class_id, truck_departure_id) VALUES
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_ALL_DAY'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '09:00'
            )
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_ALL_DAY'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '11:45'
            )
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_ALL_DAY'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '15:45'
            )
        );

COMMIT;