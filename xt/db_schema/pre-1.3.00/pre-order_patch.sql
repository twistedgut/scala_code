-- Purpose:
--  

BEGIN;

insert into flag_type values (6, 'Order');

insert into flag values (45, 'Pre-Order', (select id from flag_type where description = 'Order'));

insert into shipment_status values (11, 'Pre-Order Hold');

insert into authorisation_sub_section values (default, 2, 'Pre-Order Hold', 13);

alter table product_attribute add column pre_order boolean default false;

COMMIT;