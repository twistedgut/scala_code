BEGIN;

    CREATE SCHEMA voucher;
    ALTER SCHEMA voucher OWNER TO www;

	-- voucher 'product' table
    CREATE TABLE voucher.product (
        id integer DEFAULT nextval('product_id_seq') PRIMARY KEY,
        name text NOT NULL,
        operator_id integer REFERENCES public.operator(id) DEFERRABLE NOT NULL,
        channel_id integer REFERENCES public.channel(id) DEFERRABLE NOT NULL,
        created timestamp with time zone default now() NOT NULL,
        upload_date timestamp with time zone,
        visible boolean NOT NULL default('f'),
        landed_cost numeric(10,3),
        value integer NOT NULL,
        currency_id  integer  REFERENCES public.currency(id) DEFERRABLE NOT NULL,
        is_physical boolean NOT NULL,
        disable_scheduled_update boolean NOT NULL,
        UNIQUE (name, channel_id)
    );
    ALTER TABLE voucher.product OWNER TO www;

	-- voucher 'variant' table only for linking
	CREATE TABLE voucher.variant (
        id integer DEFAULT nextval('variant_id_seq') PRIMARY KEY,
		voucher_product_id integer REFERENCES voucher.product(id) DEFERRABLE NOT NULL
    );
    ALTER TABLE voucher.variant OWNER TO www;
	
	ALTER TABLE voucher.variant ADD UNIQUE (voucher_product_id);

	ALTER TABLE stock_order ADD COLUMN voucher_product_id integer REFERENCES voucher.product(id) DEFERRABLE;	
	 -- the two FKs are mutually exclusive
	ALTER TABLE stock_order ADD CONSTRAINT linked_to_product_or_voucher_product 
		CHECK(voucher_product_id ::int::boolean != product_id ::int::boolean);
	
	ALTER TABLE stock_order_item ADD COLUMN voucher_variant_id integer REFERENCES voucher.variant(id) DEFERRABLE;
	 -- the two FKs are mutually exclusive
	ALTER TABLE stock_order ADD CONSTRAINT linked_to_variant_or_voucher_variant 
		CHECK(voucher_product_id ::int::boolean != product_id ::int::boolean);

	
COMMIT;
