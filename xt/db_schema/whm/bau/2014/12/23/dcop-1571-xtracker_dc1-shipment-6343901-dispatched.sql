begin;

update shipment set shipment_status_id=4 where id=6343901;
insert into shipment_status_log (shipment_id, shipment_status_id, operator_id, date)
values (6343901, 4, 1, now());

commit;

