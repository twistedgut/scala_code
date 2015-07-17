BEGIN;

insert into quantity (variant_id, location_id, quantity, channel_id, status_id)
values (
    2343236,
    (select id from location where location = 'Sample Room'),
    1,
    3,
    (select id from flow.status where name = 'Sample')
);

insert into log_sample_adjustment (
	sku, location_name, operator_name, channel_id, notes, delta, balance
) 
select v.product_id || '-' || sku_padding(v.size_id), l.location, 'Application', q.channel_id,
	'Adjusted by BAU to reverse incorrect Lost adjustment', 1, 0
from variant v join quantity q on v.id=q.variant_id join location l on q.location_id=l.id
where l.location = 'Sample Room' and q.status_id = (select id from flow.status where name = 'Sample')
and q.quantity = 1
and v.id = 2343236;

COMMIT;
