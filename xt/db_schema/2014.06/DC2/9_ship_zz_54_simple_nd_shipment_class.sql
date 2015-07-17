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

COMMIT;