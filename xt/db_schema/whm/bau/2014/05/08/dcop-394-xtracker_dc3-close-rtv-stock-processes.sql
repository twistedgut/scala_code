BEGIN;

update stock_process set status_id = 4, complete = true
where group_id in (78835, 88665, 88671);

COMMIT;
