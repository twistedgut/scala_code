-- Add "EIP" as a SOS shipment class attribute

BEGIN;

insert into sos.shipment_class_attribute (name)
  values ('EIP');

COMMIT;
