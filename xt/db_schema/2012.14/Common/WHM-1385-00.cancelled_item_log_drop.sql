-- Remove cancelled_item_log table

BEGIN;
    -- Drop the table
    DROP TABLE public.cancelled_item_log;
COMMIT;
