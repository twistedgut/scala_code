BEGIN;
update stock_process set status_id = '4' where group_id IN (2839422,2929640,2852446);
COMMIT;
