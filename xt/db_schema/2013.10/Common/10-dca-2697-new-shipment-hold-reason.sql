BEGIN;

select setval('shipment_hold_reason_id_seq', (select MAX(id) FROM public.shipment_hold_reason));

insert into shipment_hold_reason (reason) values ('Failed Allocation');

COMMIT;

