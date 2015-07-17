BEGIN;
    CREATE INDEX voucher_variant_id ON shipment_item (voucher_variant_id);
COMMIT;
