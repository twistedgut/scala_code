-- It appears we have a duplicate index on stock_process.delivery_item_id -
-- let's remove one

BEGIN;
    DROP INDEX IF EXISTS
        stock_process_delivery_item_id,
        stock_process_delivery_item_id_key;
COMMIT;
