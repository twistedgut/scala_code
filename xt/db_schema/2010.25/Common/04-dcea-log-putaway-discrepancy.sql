BEGIN;

CREATE TABLE log_putaway_discrepancy (
       stock_process_id INTEGER REFERENCES public.stock_process(id) NOT NULL,
       variant_id INTEGER REFERENCES public.variant(id) NOT NULL,
       quantity INTEGER,
       ext_quantity INTEGER,
       channel_id INTEGER REFERENCES public.channel(id),
       recorded timestamp with time zone default CURRENT_TIMESTAMP
);

ALTER TABLE log_putaway_discrepancy OWNER to www;

COMMIT;