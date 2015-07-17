BEGIN;

    -- Add the new 'Express' shipment_class attribute and the associated wms_settings
    INSERT INTO sos.shipment_class_attribute (name) VALUES
        ('Express');

    -- Update all of the wms_priority settings with the latest values

    DELETE FROM sos.wms_priority;

    INSERT INTO sos.wms_priority (
            shipment_class_id,
            country_id,
            shipment_class_attribute_id,
            wms_priority,
            wms_bumped_priority,
            bumped_interval
        ) VALUES
        (
            (SELECT id FROM sos.shipment_class WHERE name = 'Standard'),
            NULL,
            NULL,
            20,
            15,
            '00:00:00'
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE name = 'Premier'),
            NULL,
            NULL,
            20,
            3,
            '02:00:00'
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE name = 'Staff'),
            NULL,
            NULL,
            20,
            NULL,
            NULL
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE name = 'Transfer'),
            NULL,
            NULL,
            20,
            NULL,
            NULL
        ),
        (
            NULL,
            (SELECT id FROM sos.country WHERE name = 'Australia'),
            NULL,
            20,
            9,
            '01:00:00'
        ),
        (
            NULL,
            (SELECT id FROM sos.country WHERE name = 'Argentina'),
            NULL,
            20,
            9,
            '01:00:00'
        ),
        (
            NULL,
            (SELECT id FROM sos.country WHERE name = 'Bahrain'),
            NULL,
            20,
            9,
            '01:00:00'
        ),
        (
            NULL,
            (SELECT id FROM sos.country WHERE name = 'Nigeria'),
            NULL,
            20,
            9,
            '01:00:00'
        ),
        (
            NULL,
            (SELECT id FROM sos.country WHERE name = 'South Africa'),
            NULL,
            20,
            9,
            '01:00:00'
        ),
        (
            NULL,
            (SELECT id FROM sos.country WHERE name = 'United Arab Emirates'),
            NULL,
            20,
            9,
            '01:00:00'
        ),
        (
            NULL,
            NULL,
            (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Nominated Day'),
            20,
            6,
            '02:00:00'
        ),
        (
            NULL,
            NULL,
            (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Express'),
            20,
            12,
            '00:00:00'
        );

COMMIT;