BEGIN;

-- sample returns
update putaway_prep_group set status_id = (select id from putaway_prep_group_status where status = 'Completed')
where group_id::int in (2344846, 2580010, 2686147);
update stock_process set complete = true, status_id = (select id from stock_process_status where status = 'Putaway')
where group_id in (2344846, 2580010, 2686147);


-- r7146
UPDATE putaway_prep_group SET status_id = 2 where id = 757638;

-- r6880
UPDATE putaway_prep_group SET status_id = 2 where id = 716763;

COMMIT;

