BEGIN;

    -- Add new Premier All Day shipment-class
    INSERT INTO sos.shipment_class (name, api_code)
        VALUES ('Premier All Day', 'PREMIER_ALL_DAY');

COMMIT;