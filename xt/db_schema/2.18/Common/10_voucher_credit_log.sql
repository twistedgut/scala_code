BEGIN;
	CREATE TABLE voucher.credit_log (
		id serial PRIMARY KEY,
		code_id integer REFERENCES voucher.code(id) DEFERRABLE NOT NULL,
		shipment_id integer REFERENCES public.shipment(id) DEFERRABLE,
		currency_id integer REFERENCES public.currency(id) DEFERRABLE NOT NULL,
	  	delta numeric(10,3) NOT NULL,
		logged timestamp with time zone default now() NOT NULL
	);
	ALTER TABLE voucher.credit_log OWNER TO www;
COMMIT;

ALTER TABLE voucher.product ALTER COLUMN value TYPE numeric(10,3);
