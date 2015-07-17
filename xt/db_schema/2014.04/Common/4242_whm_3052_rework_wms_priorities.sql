-- WHM-3052 : Create wms_priority table
BEGIN;

    CREATE TABLE sos.wms_priority (
        id SERIAL PRIMARY KEY,
        shipment_class_id INT UNIQUE REFERENCES sos.shipment_class(id) ON DELETE CASCADE,
        country_id INT UNIQUE REFERENCES sos.country(id) ON DELETE CASCADE,
        region_id INT UNIQUE REFERENCES sos.region(id) ON DELETE CASCADE,
        shipment_class_attribute_id INT UNIQUE REFERENCES sos.shipment_class_attribute(id) ON DELETE CASCADE,
        wms_priority INT NOT NULL,
        wms_bumped_priority INT,
        bumped_interval INTERVAL
    );
    ALTER TABLE sos.wms_priority OWNER TO www;
    ALTER SEQUENCE sos.wms_priority_id_seq OWNER TO www;

    INSERT INTO sos.wms_priority (shipment_class_id, wms_priority, wms_bumped_priority, bumped_interval) VALUES
        ((SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD'), 10, NULL, NULL),
        ((SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER'), 10, 1, '01:00:00'),
        ((SELECT id FROM sos.shipment_class WHERE api_code = 'STAFF'), 10, NULL, NULL),
        ((SELECT id FROM sos.shipment_class WHERE api_code = 'TRANSFER'), 10, NULL, NULL);

    INSERT INTO sos.wms_priority (shipment_class_attribute_id, wms_priority, wms_bumped_priority, bumped_interval) VALUES
        ((SELECT id FROM sos.shipment_class_attribute WHERE name = 'Nominated Day'), 10, 5, '01:00:00');

    INSERT INTO sos.wms_priority (country_id, wms_priority, wms_bumped_priority, bumped_interval) VALUES
        ((SELECT id FROM sos.country WHERE api_code = 'AU'), 10, 7, '01:00:00'),
        ((SELECT id FROM sos.country WHERE api_code = 'AR'), 10, 7, '01:00:00'),
        ((SELECT id FROM sos.country WHERE api_code = 'BH'), 10, 7, '01:00:00'),
        ((SELECT id FROM sos.country WHERE api_code = 'NG'), 10, 7, '01:00:00'),
        ((SELECT id FROM sos.country WHERE api_code = 'ZA'), 10, 7, '01:00:00'),
        ((SELECT id FROM sos.country WHERE api_code = 'AE'), 10, 7, '01:00:00');

COMMIT;