BEGIN;

insert into log_sample_adjustment (
    sku, location_name, operator_name, channel_id, notes, delta, balance
)
select v.product_id || '-' || sku_padding(v.size_id), l.location, 'Application', q.channel_id,
    'Adjusted by BAU to fix error - DCOP-462', (-1*q.quantity), 0
from quantity q join variant v on v.id=q.variant_id
join location l on q.location_id=l.id
where l.location='Transfer Pending'
and v.id not in (
    select si.variant_id
    from shipment_item si join shipment s on s.id=si.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join stock_transfer st on lsts.stock_transfer_id=st.id
    where si.shipment_item_status_id != 8 -- not Returned
)
and v.id not in (
    select si.variant_id
    from shipment_item si join shipment s on s.id=si.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join stock_transfer st on lsts.stock_transfer_id=st.id
    join return_item ri on ri.shipment_item_id=si.id
    where ri.return_item_status_id != 7 -- not Put Away
);

delete from quantity where id in (
select q.id
from quantity q join variant v on v.id=q.variant_id
join location l on q.location_id=l.id
where l.location='Transfer Pending'
and v.id not in (
    select si.variant_id
    from shipment_item si join shipment s on s.id=si.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join stock_transfer st on lsts.stock_transfer_id=st.id
    where si.shipment_item_status_id != 8 -- not Returned
)
and v.id not in (
    select si.variant_id
    from shipment_item si join shipment s on s.id=si.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join stock_transfer st on lsts.stock_transfer_id=st.id
    join return_item ri on ri.shipment_item_id=si.id
    where ri.return_item_status_id != 7 -- not Put Away
)
);

COMMIT;
