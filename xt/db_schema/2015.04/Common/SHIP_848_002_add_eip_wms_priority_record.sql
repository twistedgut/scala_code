-- Add a line to the wms_priority config section on the shipping config screen

BEGIN;

insert into sos.wms_priority (shipment_class_attribute_id, wms_priority)
values (
    (select id from sos.shipment_class_attribute where name = 'EIP'),
    20
);

COMMIT;
