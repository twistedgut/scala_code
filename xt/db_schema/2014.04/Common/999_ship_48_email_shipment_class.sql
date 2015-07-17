BEGIN;
    -- SHIP-48, add 'Email' shipment class for virtual item only shipments

    INSERT INTO sos.shipment_class (name, description, api_code, use_truck_departure_times_for_sla)
        VALUES ('Email', 'For virtual shipments', 'EMAIL', FALSE);

    INSERT INTO sos.processing_time (class_id, processing_time)
        VALUES (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'EMAIL'),
            '02:00:00'
        );
    INSERT INTO sos.wms_priority (shipment_class_id, wms_priority)
        VALUES (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'EMAIL'),
            20
        );
COMMIT;