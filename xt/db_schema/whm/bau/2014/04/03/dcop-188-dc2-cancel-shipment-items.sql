BEGIN;

-- select o.order_nr,v.product_id,v.size_id,si.id
-- from shipment_item si
-- join shipment s on si.shipment_id=s.id
-- join variant v on si.variant_id=v.id
-- join link_orders__shipment los on los.shipment_id=s.id
-- join orders o on los.orders_id=o.id
-- where si.shipment_item_status_id=9 and (
--       (o.order_nr='600235359' and v.product_id=381359 and v.size_id=5)
--    or (o.order_nr='400561897' and v.product_id=354728 and v.size_id=5)
--    or (o.order_nr='600229318' and v.product_id=327218 and v.size_id=5)
--    or (o.order_nr='21336299' and v.product_id=388227 and v.size_id=5)
--    or (o.order_nr='21337766' and v.product_id=405543 and v.size_id=5)
-- )
-- order by order_nr desc;

--  order_nr  | product_id | size_id |   id    
-- -----------+------------+---------+---------
--  600235359 |     381359 |       5 | 5032430
--  600229318 |     327218 |       5 | 4943950
--  400561897 |     354728 |       5 | 4966537
--  21337766  |     405543 |       5 | 4945264
--  21336299  |     388227 |       5 | 4938597
-- (5 rows)

insert into shipment_item_status_log(shipment_item_id,shipment_item_status_id,operator_id)
select si.id,(select id from shipment_item_status where status = 'Cancelled'),1
from shipment_item si
where
    shipment_item_status_id = (select id from shipment_item_status where status = 'Cancel Pending')
    and id in (
        5032430,
        4943950,
        4966537,
        4945264,
        4938597
    )
;

update shipment_item
set shipment_item_status_id = (select id from shipment_item_status where status = 'Cancelled')
where
    shipment_item_status_id = (select id from shipment_item_status where status = 'Cancel Pending')
    and id in (
        5032430,
        4943950,
        4966537,
        4945264,
        4938597
    )
;

COMMIT;
