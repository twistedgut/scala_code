-- GV-678: Add 'voucher_variant_id' to 'log_rtv_stock' table

BEGIN WORK;

ALTER TABLE log_rtv_stock
    ALTER COLUMN variant_id DROP NOT NULL,
    ADD COLUMN voucher_variant_id INTEGER REFERENCES voucher.variant(id),
    ADD CONSTRAINT linked_to_variant_or_voucher_variant CHECK ( COALESCE(variant_id,0)::boolean <> COALESCE(voucher_variant_id,0)::boolean )
;

COMMIT WORK;
