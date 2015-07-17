-- Restrict the weight field in shipping_attribute to three decimal places

BEGIN;

ALTER TABLE public.shipping_attribute ALTER COLUMN weight TYPE NUMERIC(20, 3);

COMMIT;
