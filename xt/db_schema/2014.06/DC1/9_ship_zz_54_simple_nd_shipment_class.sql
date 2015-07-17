BEGIN;

    -- SHIP-54. DHL Nominated day should be interpreted as its own shipment class with
    -- it's own truck schedule.

    DROP TABLE sos.nominated_day_selection_time;

    ALTER TABLE sos.processing_time DROP CONSTRAINT processing_time_class_attribute_id_fkey;
    ALTER TABLE sos.processing_time ADD CONSTRAINT processing_time_class_attribute_id_fkey
        FOREIGN KEY (class_attribute_id) REFERENCES sos.shipment_class_attribute(id)
        ON DELETE CASCADE DEFERRABLE;

    ALTER TABLE sos.processing_time_override DROP CONSTRAINT processing_time_override_major_id_fkey;
    ALTER TABLE sos.processing_time_override ADD CONSTRAINT processing_time_override_major_id_fkey
        FOREIGN KEY (major_id) REFERENCES sos.processing_time(id)
        ON DELETE CASCADE DEFERRABLE;

    ALTER TABLE sos.processing_time_override DROP CONSTRAINT processing_time_override_minor_id_fkey;
    ALTER TABLE sos.processing_time_override ADD CONSTRAINT processing_time_override_minor_id_fkey
        FOREIGN KEY (minor_id) REFERENCES sos.processing_time(id)
        ON DELETE CASCADE DEFERRABLE;

    ALTER TABLE sos.region DROP CONSTRAINT region_api_code_key;
    ALTER TABLE sos.region ADD CONSTRAINT region_api_code_key UNIQUE (country_id, api_code);

    DELETE FROM sos.shipment_class_attribute WHERE name = 'Nominated Day';

    INSERT INTO sos.shipment_class (name, description, api_code) VALUES
        ('Nominated Day', '-', 'NOMDAY');

    INSERT INTO sos.processing_time (class_id, processing_time) VALUES
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'NOMDAY' ), '02:00:00' );

    INSERT INTO sos.processing_time_override (major_id, minor_id) VALUES
        (
            (
                SELECT id FROM sos.processing_time
                WHERE class_id = ( SELECT id FROM sos.shipment_class WHERE api_code = 'NOMDAY' )
            ),
            (
                SELECT id FROM sos.processing_time
                WHERE channel_id = ( SELECT id FROM sos.channel WHERE api_code = 'TON' )
            )
        );

    INSERT INTO sos.wms_priority (shipment_class_id, wms_priority, wms_bumped_priority, bumped_interval) VALUES
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'NOMDAY' ),
            20,
            6,
            '02:00:00'
        );

    INSERT INTO sos.truck_departure__class (shipment_class_id, truck_departure_id) VALUES
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'NOMDAY' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = ( SELECT id FROM sos.carrier WHERE code = 'DHL' )
                AND departure_time = '07:30:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'NOMDAY' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = ( SELECT id FROM sos.carrier WHERE code = 'DHL' )
                AND departure_time = '13:30:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'NOMDAY' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = ( SELECT id FROM sos.carrier WHERE code = 'DHL' )
                AND departure_time = '15:45:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'NOMDAY' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = ( SELECT id FROM sos.carrier WHERE code = 'DHL' )
                AND departure_time = '17:30:00'
            )
        );

COMMIT;