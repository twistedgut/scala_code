-- SHIP-705
-- Add processing times for full sale and mixed sale shipment class attributes

BEGIN;

insert into sos.processing_time (class_attribute_id, processing_time)
values
(
    (select id from sos.shipment_class_attribute where name = 'Mixed Sale'),
    '02:30:00'
),
(
    (select id from sos.shipment_class_attribute where name = 'Full Sale'),
    '02:30:00'
);

COMMIT;
