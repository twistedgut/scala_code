BEGIN;
update allocation set status_id = 4 where status_id = 2 and id in (
    select a1.id as blocking_allocation_id
    from orders o join link_orders__shipment los on o.id=los.orders_id
    join shipment s on s.id=los.shipment_id
    join allocation a1 on a1.shipment_id=s.id
    join allocation a2 on a2.shipment_id=s.id
    where a1.prl_id in (1,3) and a2.prl_id=2 -- Full and GOH can block DCD
    and a1.status_id=2 and a2.status_id=2 -- both allocated, awaiting selection
    and s.id=3486270
    and a1.id not in (
        select a.id
        from allocation a join allocation_item ai on a.id=ai.allocation_id
        where ai.status_id in (1,2,5) -- still in progress
        and a.shipment_id=3486270
    )
);
COMMIT;