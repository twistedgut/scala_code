-- APS-726
--

begin;
--
-- select all the quantity records that are for sample sku's that are below zero.
-- count of shipment_item records (orders) by channel that have the wrong sample variant_id (so we can update the correct quantity records later).
-- select he correct stock variant_id that should have been used.
-- store in temp table.
--

select 
   q.id quantity_id, 
   q.variant_id sample_variant_id, 
   (
      select 
         count(*) 
      from 
         shipment_item si, link_orders__shipment los, orders o
      where 
         si.variant_id = q.variant_id 
         and los.shipment_id = si.shipment_id
         and o.id = los.orders_id
         and o.channel_id = q.channel_id 
   ) qty, 
   v2.id stock_variant_id,
   q.channel_id

into
   temp t_variant_fix
from
   quantity q, variant v1, variant v2
where 
   q.location_id = (select id from location where location = 'IWS') 
   and q.quantity <0
   and v1.id = q.variant_id 
   and v1.type_id = (select id from variant_type where type = 'Sample')  
   and v2.product_id = v1.product_id
   and v2.size_id = v1.size_id 
   and v2.designer_size_id = v1.designer_size_id
   and v2.type_id = (select id from variant_type where type = 'Stock');

--
-- update the incorrect shipment_item records 
--

update shipment_item set
   variant_id = (select distinct(stock_variant_id) from t_variant_fix where sample_variant_id = variant_id)
where
   variant_id in (select distinct(sample_variant_id) from t_variant_fix);

--
-- update quantity values on correct variant records
--

update quantity set
   quantity = quantity - (select t.qty from t_variant_fix t where t.stock_variant_id = quantity.variant_id and t.channel_id = quantity.channel_id)
where
   quantity.variant_id in (select t.stock_variant_id from t_variant_fix t);

--
-- delete incorrect quantity records for the sample variants 
--

delete from quantity where id in (select t_variant_fix.quantity_id from t_variant_fix);

commit;
