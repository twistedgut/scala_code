BEGIN;

insert into log_sample_adjustment (
	sku, location_name, operator_name, channel_id, notes, delta, balance
) 
select v.product_id || '-' || sku_padding(v.size_id), l.location, 'Application', q.channel_id,
	'Adjusted by BAU to fix error', -1, 0
from variant v join quantity q on v.id=q.variant_id join location l on q.location_id=l.id
where l.location = 'Sample Room' and q.status_id = (select id from flow.status where name = 'Sample')
and q.quantity = 1
and v.id = 3755767;

delete from quantity
where status_id = (select id from flow.status where name = 'Sample')
and location_id = (select id from location where location = 'Sample Room')
and quantity = 1
and variant_id = 3755767;

insert into log_sample_adjustment (
	sku, location_name, operator_name, channel_id, notes, delta, balance
) 
select v.product_id || '-' || sku_padding(v.size_id), l.location, 'Application', q.channel_id,
	'Adjusted by BAU to fix error', -1, 0
from variant v join quantity q on v.id=q.variant_id join location l on q.location_id=l.id
where l.location = 'Transfer Pending' and q.status_id = (select id from flow.status where name = 'Transfer Pending')
and q.quantity = 1
and v.id = 3833944;

delete from quantity
where status_id = (select id from flow.status where name = 'Transfer Pending')
and location_id = (select id from location where location = 'Transfer Pending')
and quantity = 1
and variant_id = 3833944;

insert into log_sample_adjustment (
	sku, location_name, operator_name, channel_id, notes, delta, balance
) 
select v.product_id || '-' || sku_padding(v.size_id), l.location, 'Application', q.channel_id,
	'Adjusted by BAU to fix error', -1, 0
from variant v join quantity q on v.id=q.variant_id join location l on q.location_id=l.id
where l.location = 'Transfer Pending' and q.status_id = (select id from flow.status where name = 'Transfer Pending')
and q.quantity = 1
and v.id = 4161068;

delete from quantity
where status_id = (select id from flow.status where name = 'Transfer Pending')
and location_id = (select id from location where location = 'Transfer Pending')
and quantity = 1
and variant_id = 4161068;

COMMIT;

