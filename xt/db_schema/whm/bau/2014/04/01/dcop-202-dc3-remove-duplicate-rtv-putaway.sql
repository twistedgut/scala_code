BEGIN;

delete from quantity
where location_id = (select id from location where location='032R-2101A')
 and variant_id = (select id from variant where product_id=416221 and size_id=16)
 and status_id = (select id from flow.status where name = 'RTV Process');

delete from rtv_quantity
where location_id = (select id from location where location='032R-2101A')
 and variant_id = (select id from variant where product_id=416221 and size_id=16);

delete from log_rtv_stock
where id = (select id from log_rtv_stock
where variant_id = (select id from variant where product_id=416221 and size_id=16)
  and notes like 'Quarantine to%'
order by date desc
limit 1);

COMMIT;
