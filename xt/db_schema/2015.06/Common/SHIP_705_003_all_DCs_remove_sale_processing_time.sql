-- SHIP-705
-- Remove "Sale" processing time

BEGIN;

delete from sos.processing_time
where class_attribute_id = (
    select id from sos.shipment_class_attribute where name = 'Sale'
);

COMMIT;
