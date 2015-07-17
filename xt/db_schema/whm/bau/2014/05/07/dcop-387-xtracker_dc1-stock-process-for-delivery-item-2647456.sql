BEGIN;

update stock_process set status_id = 1, complete = false where delivery_item_id = 2647456;

COMMIT;
