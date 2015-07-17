-- Add a unique index to stock_transfer_type(type)
BEGIN;
    ALTER TABLE public.stock_transfer_type ADD UNIQUE (type);
COMMIT;
