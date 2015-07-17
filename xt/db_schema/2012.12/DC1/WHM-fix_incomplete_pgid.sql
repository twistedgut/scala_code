BEGIN;
    UPDATE stock_process
    SET status_id = (SELECT id from stock_process_status where status = 'Putaway'),
        complete = true
    WHERE group_id = 1652199;
COMMIT;
