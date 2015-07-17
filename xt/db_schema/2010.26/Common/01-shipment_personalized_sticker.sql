BEGIN;

    ALTER TABLE shipment
        ADD COLUMN sticker VARCHAR(255);

COMMIT;
