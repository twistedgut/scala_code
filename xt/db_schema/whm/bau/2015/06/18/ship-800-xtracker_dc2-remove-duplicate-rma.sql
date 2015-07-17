BEGIN;
-- DC2 cancel duplicate RMAs

UPDATE return
    SET cancellation_date = current_timestamp,
        return_status_id  = (SELECT id FROM return_status  WHERE  status = 'Cancelled')
    WHERE rma_number in ( 'U3744714-1587242', 'U3774418-1617650', 'U3852123-1640436',
    'U3552728-1629173', 'U3600621-1522677', 'U3899761-1677637', 'U3899761-1677638');

-- Check if there are any remaining duplicate RMAs
-- cancel duplicate sample returns
-- produce list of returns to cancel - just for reference
  select r1.rma_number, r1.creation_date, r2.rma_number , r2.creation_date, q.channel_id
  from return r1
  join shipment s on s.id=r1.shipment_id
  join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
  join return r2 on s.id=r2.shipment_id
  join shipment_item si on si.shipment_id=s.id
  join quantity q on q.variant_id=si.variant_id
  where q.status_id = (select id from flow.status where name = 'Transfer Pending')
  and q.quantity = 1
  and r1.return_status_id = (select id from return_status where status = 'Awaiting Return')
  and r2.return_status_id = (select id from return_status where status = 'Complete')
  order by r1.id;

  -- do the update - set status to cancelled for duplicates
  update return set cancellation_date = current_timestamp, return_status_id = (select id from return_status where status = 'Cancelled')
  where id in (
    select r1.id
    from return r1
    join shipment s on s.id=r1.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join return r2 on s.id=r2.shipment_id
    join shipment_item si on si.shipment_id=s.id
    join quantity q on q.variant_id=si.variant_id
    where q.status_id = (select id from flow.status where name = 'Transfer Pending')
    and q.quantity = 1
    and r1.return_status_id = (select id from return_status where status = 'Awaiting Return')
    and r2.return_status_id = (select id from return_status where status = 'Complete') );

COMMIT;
