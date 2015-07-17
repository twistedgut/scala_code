BEGIN;

    -- processing_time_overrides for DC1
    INSERT INTO sos.processing_time_override (major_id, minor_id) VALUES
    (
        (
            SELECT id FROM sos.processing_time
            WHERE class_id = (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER')
        ),
        (
            SELECT id FROM sos.processing_time
            WHERE class_attribute_id = (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Nominated Day')
        )
    ),
    (
        (
            SELECT id FROM sos.processing_time
            WHERE class_id = (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER')
        ),
        (
            SELECT id FROM sos.processing_time
            WHERE channel_id = (SELECT id FROM sos.channel WHERE api_code = 'TON')
        )
    ),
    (
        (
            SELECT id FROM sos.processing_time
            WHERE country_id = (SELECT id FROM sos.country WHERE api_code = 'AU')
        ),
        (
            SELECT id FROM sos.processing_time
            WHERE class_id = (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD')
        )
    ),
    (
        (
            SELECT id FROM sos.processing_time
            WHERE class_attribute_id = (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Nominated Day')
        ),
        (
            SELECT id FROM sos.processing_time
            WHERE class_id = (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD')
        )
    ),
    (
        (
            SELECT id FROM sos.processing_time
            WHERE class_attribute_id = (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Nominated Day')
        ),
        (
            SELECT id FROM sos.processing_time
            WHERE channel_id = (SELECT id FROM sos.channel WHERE api_code = 'TON')
        )
    );

COMMIT;