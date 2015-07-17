BEGIN;

-- list the processes we'll be updating
select sp1.id, sp1.group_id, sp1.status_id, sp2.id, sp2.group_id, sp2.status_id
from stock_process sp1 join stock_process sp2 on sp1.delivery_item_id = sp2.delivery_item_id
join link_delivery_item__return_item ldiri on ldiri.delivery_item_id = sp2.delivery_item_id
where sp1.type_id = 1 -- main
and sp2.type_id = 2 -- faulty
and sp1.id>2000000 and sp2.id>2000000 -- ignore anything really old
and sp1.quantity = 1 and sp2.quantity = 1
order by sp1.id;

-- do the update
update stock_process set complete = true, status_id = 4
where group_id in (
    select sp2.group_id
    from stock_process sp1 join stock_process sp2 on sp1.delivery_item_id = sp2.delivery_item_id
    join link_delivery_item__return_item ldiri on ldiri.delivery_item_id = sp2.delivery_item_id
    where sp1.type_id = 1 -- main
    and sp2.type_id = 2 -- faulty
    and sp1.id>2000000 and sp2.id>2000000 -- ignore anything really old
    and sp1.quantity = 1 and sp2.quantity = 1 
)
and complete = false and status_id = 1;

COMMIT;
