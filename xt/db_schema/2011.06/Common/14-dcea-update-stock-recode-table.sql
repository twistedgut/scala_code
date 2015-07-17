-- Create stock_recode table

BEGIN;

ALTER TABLE public.stock_recode ADD COLUMN notes varchar(255);

COMMIT;
