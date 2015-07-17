BEGIN;

    -- Add 'is_slow' column to shipping_charge table
    ALTER TABLE shipping_charge ADD COLUMN is_slow BOOLEAN DEFAULT FALSE;

    -- ... AND 'slow' shipment_class_Attribute to SOS
    INSERT INTO sos.shipment_class_attribute (name)
        VALUES ('Slow');

COMMIT;