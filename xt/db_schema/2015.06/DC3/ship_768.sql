BEGIN;

    -- DC3 requires the wms-priority values for Prem Anytime
    INSERT INTO sos.wms_priority (shipment_class_id, wms_priority, wms_bumped_priority, bumped_interval) VALUES
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_ALL_DAY'),
            20,
            3,
            '12:00:00'
        )
    ;

COMMIT;

