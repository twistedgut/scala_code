BEGIN;

    -- shipping_charges now have an 'is_express' flag to let us (SOS really) know if they
    -- should be considered oh so slightly higher priority than non-express standard
    -- shipments
    ALTER TABLE shipping_charge ADD COLUMN is_express BOOLEAN NOT NULL DEFAULT false;

COMMIT;