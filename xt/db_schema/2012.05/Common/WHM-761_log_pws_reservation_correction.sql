-- Add a log table to track automated pws reservation updates

BEGIN;
    CREATE TABLE log_pws_reservation_correction (
        id serial PRIMARY KEY,
        channel_id integer NOT NULL REFERENCES public.channel(id),
        pws_customer_id text NOT NULL,
        variant_id integer NOT NULL REFERENCES public.variant(id),
        xt_quantity integer NOT NULL,
        pws_quantity integer NOT NULL,
        created timestamp with time zone NOT NULL default now()
    );
    ALTER TABLE log_pws_reservation_correction OWNER TO www;
COMMIT;
