--Remove silly 'Unknown' statuses

BEGIN;
    DELETE FROM delivery_status WHERE status = 'Unknown';
    DELETE FROM stock_process_status WHERE status = 'Unknown';
COMMIT;
