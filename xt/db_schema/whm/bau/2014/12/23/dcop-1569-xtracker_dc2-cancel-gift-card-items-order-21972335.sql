begin;

insert into shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id, date)
select id, (select id from shipment_item_status where status = 'Cancelled'), 1, now()
from shipment_item where shipment_id = 3524995;

update shipment_item set shipment_item_status_id = (
    select id from shipment_item_status where status = 'Cancelled'
), container_id = null
where shipment_id = 3524995;

update container set status_id = (select id from container_status where name = 'Available') where id = 'T0066137';

commit;
