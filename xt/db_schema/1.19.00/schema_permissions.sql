-- some tests are failing with "permission denied for relation X" errors
--
-- I think that the way to resolve these are to make sure that we've correctly
-- set the table owner to www
BEGIN;
    ALTER TABLE public.stock_transfer OWNER TO www;
    ALTER TABLE public.stock_transfer_status OWNER TO www;
    ALTER TABLE public.stock_transfer_type OWNER TO www;
COMMIT;
