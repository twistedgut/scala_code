BEGIN;

select v.product_id,v.size_id,q.*,l.location
from variant v
join quantity q on q.variant_id=v.id
join location l on l.id=q.location_id
where q.channel_id=2 AND (
   (product_id=389577 and size_id=012)
OR (product_id=391526 and size_id=012)
OR (product_id=392121 and size_id=012)
OR (product_id=398290 and size_id=013)
OR (product_id=400063 and size_id=014)
OR (product_id=401940 and size_id=011)
OR (product_id=402550 and size_id=012)
OR (product_id=403244 and size_id=013)
OR (product_id=407609 and size_id=010)
OR (product_id=408699 and size_id=014)
OR (product_id=408783 and size_id=014)
OR (product_id=410587 and size_id=010)
OR (product_id=411101 and size_id=013)
OR (product_id=412042 and size_id=011)
OR (product_id=416416 and size_id=012)
OR (product_id=417253 and size_id=012)
OR (product_id=418918 and size_id=013)
OR (product_id=429392 and size_id=010)
OR (product_id=430066 and size_id=012)
OR (product_id=431659 and size_id=005)
OR (product_id=373862 and size_id=011)
);

insert into log_sample_adjustment (
    sku, location_name, operator_name, channel_id, notes, delta, balance
)
select v.product_id || '-' || sku_padding(v.size_id),
       l.location, 'Application', q.channel_id,
       'Adjusted by BAU to fix error', -1, 0
from variant v
join quantity q on v.id=q.variant_id
join location l on q.location_id=l.id
where l.location = 'Transfer Pending'
and q.status_id = (
 select id from flow.status where name = 'Transfer Pending'
)
AND q.channel_id=2 AND (
   (product_id=389577 and size_id=012)
OR (product_id=391526 and size_id=012)
OR (product_id=392121 and size_id=012)
OR (product_id=398290 and size_id=013)
OR (product_id=400063 and size_id=014)
OR (product_id=401940 and size_id=011)
OR (product_id=402550 and size_id=012)
OR (product_id=403244 and size_id=013)
OR (product_id=407609 and size_id=010)
OR (product_id=408699 and size_id=014)
OR (product_id=408783 and size_id=014)
OR (product_id=410587 and size_id=010)
OR (product_id=411101 and size_id=013)
OR (product_id=412042 and size_id=011)
OR (product_id=416416 and size_id=012)
OR (product_id=417253 and size_id=012)
OR (product_id=418918 and size_id=013)
OR (product_id=429392 and size_id=010)
OR (product_id=430066 and size_id=012)
OR (product_id=431659 and size_id=005)
OR (product_id=373862 and size_id=011)
);

delete from quantity
where id in (
select q.id
from variant v
join quantity q on v.id=q.variant_id
join location l on q.location_id=l.id
where l.location = 'Transfer Pending'
and q.status_id = (
 select id from flow.status where name = 'Transfer Pending'
)
AND q.channel_id=2 AND (
   (product_id=389577 and size_id=012)
OR (product_id=391526 and size_id=012)
OR (product_id=392121 and size_id=012)
OR (product_id=398290 and size_id=013)
OR (product_id=400063 and size_id=014)
OR (product_id=401940 and size_id=011)
OR (product_id=402550 and size_id=012)
OR (product_id=403244 and size_id=013)
OR (product_id=407609 and size_id=010)
OR (product_id=408699 and size_id=014)
OR (product_id=408783 and size_id=014)
OR (product_id=410587 and size_id=010)
OR (product_id=411101 and size_id=013)
OR (product_id=412042 and size_id=011)
OR (product_id=416416 and size_id=012)
OR (product_id=417253 and size_id=012)
OR (product_id=418918 and size_id=013)
OR (product_id=429392 and size_id=010)
OR (product_id=430066 and size_id=012)
OR (product_id=431659 and size_id=005)
OR (product_id=373862 and size_id=011)
)
);

update stock_process
set complete=true
where id in (select id from (
select v.product_id,v.size_id,sp.id
from variant v
join shipment_item si on si.variant_id=v.id
join link_delivery_item__shipment_item disi on disi.shipment_item_id=si.id
join delivery_item di on di.id=disi.delivery_item_id
join stock_process sp on sp.delivery_item_id=di.id
where not sp.complete
UNION
select v.product_id,v.size_id,sp.id
from variant v
join return_item ri on ri.variant_id=v.id
join link_delivery_item__return_item diri on diri.return_item_id=ri.id
join delivery_item di on di.id=diri.delivery_item_id
join stock_process sp on sp.delivery_item_id=di.id
where not sp.complete
UNION
select v.product_id,v.size_id,sp.id
from variant v
join stock_order_item soi on soi.variant_id=v.id
join link_delivery_item__stock_order_item disoi on disoi.stock_order_item_id=soi.id
join delivery_item di on di.id=disoi.delivery_item_id
join stock_process sp on sp.delivery_item_id=di.id
where not sp.complete
UNION
select v.product_id,v.size_id,sp.id
from variant v
join quarantine_process qp on qp.variant_id=v.id
join link_delivery_item__quarantine_process diqp on diqp.quarantine_process_id=qp.id
join delivery_item di on di.id=diqp.delivery_item_id
join stock_process sp on sp.delivery_item_id=di.id
where not sp.complete
) sps
where
   (product_id=389577 and size_id=012)
OR (product_id=391526 and size_id=012)
OR (product_id=392121 and size_id=012)
OR (product_id=398290 and size_id=013)
OR (product_id=400063 and size_id=014)
OR (product_id=401940 and size_id=011)
OR (product_id=402550 and size_id=012)
OR (product_id=403244 and size_id=013)
OR (product_id=407609 and size_id=010)
OR (product_id=408699 and size_id=014)
OR (product_id=408783 and size_id=014)
OR (product_id=410587 and size_id=010)
OR (product_id=411101 and size_id=013)
OR (product_id=412042 and size_id=011)
OR (product_id=416416 and size_id=012)
OR (product_id=417253 and size_id=012)
OR (product_id=418918 and size_id=013)
OR (product_id=429392 and size_id=010)
OR (product_id=430066 and size_id=012)
OR (product_id=431659 and size_id=005)
OR (product_id=373862 and size_id=011)
)
;

COMMIT;
