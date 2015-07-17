BEGIN;


ALTER TABLE public.customer ADD COLUMN
    prev_order_count INTEGER NOT NULL DEFAULT 0;


COMMIT;
