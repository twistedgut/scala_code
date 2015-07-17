BEGIN;
    ALTER TABLE public.stock_process ALTER COLUMN status_id SET NOT NULL;
    ALTER TABLE public.stock_process ALTER COLUMN type_id SET NOT NULL;
    ALTER TABLE public.stock_process ALTER COLUMN delivery_item_id SET NOT NULL;
COMMIT;
