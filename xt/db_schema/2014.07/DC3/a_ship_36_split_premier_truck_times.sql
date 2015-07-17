BEGIN;

    -- Remove 'Premier' from SOS and split in to the new 'Premier Daytime' and
    -- 'Premier Evening', each with their own truck times

    ALTER TABLE sos.processing_time
    DROP CONSTRAINT processing_time_class_id_fkey,
    ADD CONSTRAINT processing_time_class_id_fkey
        FOREIGN KEY (class_id)
        REFERENCES sos.shipment_class(id)
        ON DELETE CASCADE DEFERRABLE;

    ALTER TABLE sos.processing_time_override
    DROP CONSTRAINT processing_time_override_minor_id_fkey,
    ADD CONSTRAINT processing_time_override_minor_id_fkey
        FOREIGN KEY (minor_id)
        REFERENCES sos.processing_time(id)
        ON DELETE CASCADE DEFERRABLE;

    ALTER TABLE sos.processing_time_override
    DROP CONSTRAINT processing_time_override_major_id_fkey,
    ADD CONSTRAINT processing_time_override_major_id_fkey
        FOREIGN KEY (major_id)
        REFERENCES sos.processing_time(id)
        ON DELETE CASCADE DEFERRABLE;

    DELETE FROM sos.shipment_class WHERE api_code = 'PREMIER';
    ALTER TABLE sos.shipment_class DROP COLUMN description;

    INSERT INTO sos.shipment_class (name, api_code) VALUES
        ('Premier Daytime', 'PREMIER_DAYTIME'),
        ('Premier Evening', 'PREMIER_EVENING');

    INSERT INTO sos.processing_time (class_id, processing_time) VALUES
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_DAYTIME'), '01:45:00' ),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_EVENING'), '01:45:00' );

    INSERT INTO sos.processing_time_override (major_id, minor_id) VALUES
        (
            (
                SELECT id FROM sos.processing_time
                WHERE class_id = (
                    SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_DAYTIME'
                )
            ),
            (
                SELECT id FROM sos.processing_time
                WHERE channel_id = (
                    SELECT id FROM sos.channel WHERE api_code = 'TON'
                )
            )
        ),
        (
            (
                SELECT id FROM sos.processing_time
                WHERE class_id = (
                    SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_EVENING'
                )
            ),
            (
                SELECT id FROM sos.processing_time
                WHERE channel_id = (
                    SELECT id FROM sos.channel WHERE api_code = 'TON'
                )
            )
        );

    INSERT INTO sos.wms_priority (shipment_class_id, wms_priority, wms_bumped_priority, bumped_interval) VALUES
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_DAYTIME' ),
            20,
            3,
            '02:00:00'
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_EVENING' ),
            20,
            3,
            '02:00:00'
        );

    INSERT INTO sos.truck_departure__class ( shipment_class_id, truck_departure_id ) VALUES
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_DAYTIME' ),
            (
                SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP' )
                AND departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_EVENING' ),
            (
                SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP' )
                AND departure_time = '15:45:00'
            )
        );

COMMIT;