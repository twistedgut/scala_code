-- DCA-744 DCA-755: Add 'voucher_variant_id' to 'putaway_prep_item' table
-- and also add the constraint: 'variant_id' and 'voucher_variant_id' cannot both be null

BEGIN;

-- Remove rows that might violate the new constraint
TRUNCATE putaway_prep_item;

-- Allow 'variant_id' column to be null
ALTER TABLE putaway_prep_item ALTER COLUMN variant_id DROP NOT NULL;

-- Add 'voucher_variant_id' column, also able to be null
ALTER TABLE putaway_prep_item ADD COLUMN voucher_variant_id INTEGER REFERENCES voucher.variant(id) DEFERRABLE;

-- Add a constraint: 'variant_id' and 'voucher_variant_id' cannot both be null
ALTER TABLE putaway_prep_item
    ADD CONSTRAINT linked_to_variant_or_voucher_variant
    CHECK( COALESCE(variant_id,0)::boolean <> COALESCE(voucher_variant_id,0)::boolean );

COMMIT;
