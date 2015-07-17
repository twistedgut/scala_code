-- Remove duplicate constraint:
-- postgres@xtdc1-whm xtracker=# \d stock_order
--                                             Table "public.stock_order"
--          Column          │            Type             │                        Modifiers
-- ─────────────────────────┼─────────────────────────────┼──────────────────────────────────────────────────────────
-- ...
-- Check constraints:
--     "linked_to_product_or_voucher_product" CHECK (voucher_product_id::boolean <> product_id::boolean)
--     "linked_to_variant_or_voucher_variant" CHECK (voucher_product_id::boolean <> product_id::boolean)

BEGIN;
    ALTER TABLE stock_order DROP CONSTRAINT IF EXISTS linked_to_variant_or_voucher_variant;
COMMIT;
