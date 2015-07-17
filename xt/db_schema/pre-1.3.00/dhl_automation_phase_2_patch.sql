-- Purpose:
--  

BEGIN;

-- rename the UK shipment type to Domestic
update shipment_type set type = 'Domestic' where type = 'UK';

-- rename London premier shipment type to Premier
update shipment_type set type = 'Premier' where type = 'London Premier';

-- add new field to shipment item table
alter table shipment_item add column shipment_box_id integer references shipment_box(id) null;

-- add new field(s) to shipment_box table
ALTER TABLE shipment_box ADD COLUMN licence_plate_number varchar(255) null;

COMMIT;