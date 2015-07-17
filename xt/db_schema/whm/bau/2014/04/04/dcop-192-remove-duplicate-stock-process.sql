BEGIN;

-- Delivery is associated with 2 stock processes, so delete the duplicate entry
    delete from stock_process where group_id = 2362005;

COMMIT;
