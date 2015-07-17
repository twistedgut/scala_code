-- SHIP-705 DC2
-- Add in all the old overrides for Sale to Mixed Sale and Full Sale
-- Apologies for parenthesis soup. These tables are weird.

BEGIN;

insert into sos.processing_time_override(major_id, minor_id)
values ( -- Add full sale overrides
  (select id from sos.processing_time where class_id =
    (select id from sos.shipment_class where name = 'Premier Daytime')),
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Full Sale'))
),(
  (select id from sos.processing_time where class_id =
    (select id from sos.shipment_class where name = 'Premier All Day')),
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Full Sale'))
),(
  (select id from sos.processing_time where class_id =
    (select id from sos.shipment_class where name = 'Premier Evening')),
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Full Sale'))
),(
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Express')),
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Full Sale'))
),(  -- Add mixed sale overrides
  (select id from sos.processing_time where class_id =
    (select id from sos.shipment_class where name = 'Premier Daytime')),
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Mixed Sale'))
),(
  (select id from sos.processing_time where class_id =
    (select id from sos.shipment_class where name = 'Premier All Day')),
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Mixed Sale'))
),(
  (select id from sos.processing_time where class_id =
    (select id from sos.shipment_class where name = 'Premier Evening')),
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Mixed Sale'))
),(
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Express')),
  (select id from sos.processing_time where class_attribute_id =
    (select id from sos.shipment_class_attribute where name = 'Mixed Sale'))
);


COMMIT;
