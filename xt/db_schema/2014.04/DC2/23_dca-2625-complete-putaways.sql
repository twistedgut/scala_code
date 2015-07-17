BEGIN;

CREATE OR REPLACE FUNCTION close_completed_putaway_prep_groups()
RETURNS VOID AS $$
DECLARE
    ppg_id INTEGER;
    sp_group_id INTEGER;

BEGIN

FOR ppg_id, sp_group_id IN
    select ppg.id, sp.group_id
    from putaway_prep_group ppg join stock_process sp on ppg.group_id=sp.group_id
    join putaway_prep_inventory ppi on ppi.putaway_prep_group_id=ppg.id
    join putaway_prep_container ppc on ppi.putaway_prep_container_id=ppc.id
    where sp.complete is false
    and sp.quantity > 0
    and ppg.status_id = (select id from putaway_prep_group_status where status = 'In Progress')
    and ppc.putaway_prep_status_id = (select id from putaway_prep_container_status where status = 'Complete')
    group by ppg.id, sp.group_id
    having sum(ppi.quantity) = sum(sp.quantity)
    order by sp.group_id
LOOP
    EXECUTE 'update putaway_prep_group set status_id = (select id from putaway_prep_group_status where status = ''Completed'') where id = ' || ppg_id;
    EXECUTE 'update stock_process set complete = true where group_id = ' || sp_group_id;
END LOOP;

END;
$$ LANGUAGE plpgsql;

SELECT close_completed_putaway_prep_groups();

-- a special case because it was in 3 containers so the query above doesn't work
update putaway_prep_group set status_id = (select id from putaway_prep_group_status where status = 'Completed') where group_id = 2066918;
update stock_process set complete = true where group_id = 2066918;

COMMIT;
