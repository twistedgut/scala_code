BEGIN;
    ALTER TABLE public.stock_order ALTER COLUMN purchase_order_id SET NOT NULL;

    -- Set any null values to 'Unknown'
    UPDATE public.stock_order SET status_id=(SELECT id FROM stock_order_status WHERE status='Unknown')
        WHERE status_id IS NULL;
    ALTER TABLE public.stock_order ALTER COLUMN status_id SET NOT NULL;

    -- Set any null values to 'Unknown'
    UPDATE public.stock_order SET type_id=(SELECT id FROM stock_order_type WHERE type='Unknown')
        WHERE type_id IS NULL;
    ALTER TABLE public.stock_order ALTER COLUMN type_id SET NOT NULL;
COMMIT;
