-- DCEA-617
-- Create orphan_item table
-- This table will hold SKU's which are marked as orphans.
-- An orphan is an item which we don't know anything about.
-- canceled items will also be considered orphan but just from the perspective of the view

BEGIN;

    CREATE TABLE public.orphan_item (
    	id SERIAL PRIMARY KEY,
	variant_id integer         REFERENCES public.variant(id) DEFERRABLE,
	voucher_variant_id integer REFERENCES voucher.variant(id) DEFERRABLE,
	container_id VARCHAR(255)  REFERENCES public.container(id) DEFERRABLE NOT NULL,
	CONSTRAINT linked_to_variant_or_voucher_variant CHECK( COALESCE(variant_id,0)::boolean <> COALESCE(voucher_variant_id,0)::boolean )
    );

    ALTER TABLE public.orphan_item OWNER to www;

COMMIT;
