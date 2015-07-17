-- RES-W127

BEGIN;

-- to find DCD allocations blocked by short picked full allocations
select o.order_nr, s.id as shipment_id, s.date as shipment_date, a1.id as blocking_allocation_id, a2.id as blocked_allocation_id
from orders o join link_orders__shipment los on o.id=los.orders_id
join shipment s on s.id=los.shipment_id
join allocation a1 on a1.shipment_id=s.id
join allocation a2 on a2.shipment_id=s.id
where a1.prl_id =1  and a2.prl_id=2
and a1.status_id=5 and a2.status_id=2
and s.shipment_status_id in (2,3)
and a1.id not in (
    select a.id
    from allocation a join allocation_item ai on a.id=ai.allocation_id
    where ai.status_id = 6
    and a.status_id = 5
    and a.shipment_id in (select id from shipment where shipment_status_id in (2,3))
);
 
-- to find DCD allocations blocked by failed allocation full allocations
select o.order_nr, s.id as shipment_id, s.date as shipment_date, a1.id as blocking_allocation_id, a2.id as blocked_allocation_id
from orders o join link_orders__shipment los on o.id=los.orders_id
join shipment s on s.id=los.shipment_id
join allocation a1 on a1.shipment_id=s.id
join allocation a2 on a2.shipment_id=s.id
where a1.prl_id =1  and a2.prl_id=2
and a1.status_id=2 and a2.status_id=2
and s.shipment_status_id in (2,3)
and a1.id not in (
select a.id
from allocation a join allocation_item ai on a.id=ai.allocation_id
where ai.status_id = 2
and a.status_id = 2
and a.shipment_id in (select id from shipment where shipment_status_id in (2,3))
);

update allocation set status_id = 4 where status_id = 5 and id in (
    select a1.id
    from orders o join link_orders__shipment los on o.id=los.orders_id
    join shipment s on s.id=los.shipment_id
    join allocation a1 on a1.shipment_id=s.id
    join allocation a2 on a2.shipment_id=s.id
    where a1.prl_id =1  and a2.prl_id=2
    and a1.status_id=5 and a2.status_id=2
    and s.shipment_status_id in (2,3)
    and a1.id not in (
        select a.id
        from allocation a join allocation_item ai on a.id=ai.allocation_id
        where ai.status_id = 6
        and a.status_id = 5
        and a.shipment_id in (select id from shipment where shipment_status_id in (2,3))
    )
);
update allocation set status_id = 4 where status_id = 2 and id in (
    select a1.id
    from orders o join link_orders__shipment los on o.id=los.orders_id
    join shipment s on s.id=los.shipment_id
    join allocation a1 on a1.shipment_id=s.id
    join allocation a2 on a2.shipment_id=s.id
    where a1.prl_id =1  and a2.prl_id=2
    and a1.status_id = 2 and a2.status_id=2
    and s.shipment_status_id in (2,3)
    and a1.id not in (
        select a.id
        from allocation a join allocation_item ai on a.id=ai.allocation_id
        where ai.status_id = 2
        and a.status_id = 2
        and a.shipment_id in (select id from shipment where shipment_status_id in (2,3))
    )
);

COMMIT;
