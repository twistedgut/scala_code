BEGIN;

    -- Updated SOS processing times
    DELETE FROM sos.processing_time;

    INSERT INTO sos.processing_time (class_id, processing_time) VALUES
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD'), '02:00:00'),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER'), '01:30:00'),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'TRANSFER'), '24:00:00'),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'STAFF'), '168:00:00'),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'EMAIL'), '24:00:00');

    INSERT INTO sos.processing_time (class_attribute_id, channel_id, processing_time) VALUES
        ( (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Nominated Day'), NULL, '02:00:00'),
        ( NULL, (SELECT id FROM sos.channel WHERE api_code = 'TON'), '24:00:00');


COMMIT;