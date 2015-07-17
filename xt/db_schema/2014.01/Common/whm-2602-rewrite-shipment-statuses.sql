begin;

delete from shipment_status_log where shipment_status_id = (select id from shipment_status where status='SLA End Timer');
delete from shipment_status where status='SLA End Timer';

commit;
