-- GV-395,GV-450: Add 'voucher_variant_id' to 'shipment_item' table and also add following constraints:
--                    * must have either a variant_id or voucher_variant_id
--                    * must have a voucher_variant_id to have a voucher_code_id

BEGIN WORK;

-- Drop previous created constraint 
ALTER TABLE shipment_item DROP CONSTRAINT linked_to_variant_or_voucher_code;

-- Add 'voucher_variant_id' column
ALTER TABLE shipment_item ADD COLUMN voucher_variant_id INTEGER REFERENCES voucher.variant(id);

-- Add new constraints
ALTER TABLE shipment_item   ADD CONSTRAINT linked_to_variant_or_voucher_variant CHECK( COALESCE(variant_id,0)::boolean <> COALESCE(voucher_variant_id,0)::boolean ),
                            ADD CONSTRAINT voucher_variant_exists_to_have_voucher_code CHECK( ((COALESCE(voucher_code_id,0)::boolean OR NOT COALESCE(voucher_code_id,0)::boolean) = COALESCE(voucher_variant_id,0)::boolean) or (NOT COALESCE(voucher_code_id,0)::boolean AND COALESCE(variant_id,0)::boolean) )
;

COMMIT WORK;
