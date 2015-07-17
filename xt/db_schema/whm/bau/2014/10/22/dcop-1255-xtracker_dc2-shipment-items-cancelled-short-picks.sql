BEGIN;
  
insert into shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    select
        distinct si.id,
        (select id from shipment_item_status where status = 'Cancelled'),
        (select id from operator where name = 'Application')
    from shipment s join allocation a on s.id=a.shipment_id 
    join shipment_item si on si.shipment_id=s.id 
    join allocation_item ai on ai.shipment_item_id=si.id 
    where si.shipment_item_status_id=(select id from shipment_item_status where status = 'Cancel Pending')
    and ai.status_id=(select id from allocation_item_status where status = 'short')
    and s.id not in (
        select s.id
        from shipment s join allocation a on s.id=a.shipment_id 
        join shipment_item si on si.shipment_id=s.id 
        join allocation_item ai on ai.shipment_item_id=si.id 
        where si.shipment_item_status_id=(select id from shipment_item_status where status = 'Cancel Pending')
        and ai.status_id=(select id from allocation_item_status where status = 'picking')
    )
;

update shipment_item
    set shipment_item_status_id = (select id from shipment_item_status where status = 'Cancelled')
    where id in (
        select si.id
        from shipment s join allocation a on s.id=a.shipment_id 
        join shipment_item si on si.shipment_id=s.id 
        join allocation_item ai on ai.shipment_item_id=si.id 
        where si.shipment_item_status_id=(select id from shipment_item_status where status = 'Cancel Pending')
        and ai.status_id=(select id from allocation_item_status where status = 'short')
        and s.id not in (
            select s.id
            from shipment s join allocation a on s.id=a.shipment_id 
            join shipment_item si on si.shipment_id=s.id 
            join allocation_item ai on ai.shipment_item_id=si.id 
            where si.shipment_item_status_id=(select id from shipment_item_status where status = 'Cancel Pending')
            and ai.status_id=(select id from allocation_item_status where status = 'picking')
        )
    );
 
COMMIT;
