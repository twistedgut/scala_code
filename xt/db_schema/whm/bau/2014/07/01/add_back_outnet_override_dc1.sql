BEGIN;

    -- OUTNET premier override got removed by cascade delete :/ put it back
    INSERT INTO sos.processing_time_override (major_id, minor_id) VALUES
    (
        (
            SELECT id FROM sos.processing_time
            WHERE class_id = (SELECT id FROM sos.shipment_class WHERE api_code = 'NOMDAY')
        ),
        (
            SELECT id FROM sos.processing_time
            WHERE channel_id = (SELECT id FROM sos.channel WHERE api_code = 'TON')
        )
    ),
    (
        (
            SELECT id FROM sos.processing_time
            WHERE class_id = (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_DAYTIME')
        ),
        (
            SELECT id FROM sos.processing_time
            WHERE channel_id = (SELECT id FROM sos.channel WHERE api_code = 'TON')
        )
    ),
    (
        (
            SELECT id FROM sos.processing_time
            WHERE class_id = (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_EVENING')
        ),
        (
            SELECT id FROM sos.processing_time
            WHERE channel_id = (SELECT id FROM sos.channel WHERE api_code = 'TON')
        )
    ),
    (
        (
            SELECT id FROM sos.processing_time
            WHERE class_id = (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_ALL_DAY')
        ),
        (
            SELECT id FROM sos.processing_time
            WHERE channel_id = (SELECT id FROM sos.channel WHERE api_code = 'TON')
        )
    );

COMMIT;