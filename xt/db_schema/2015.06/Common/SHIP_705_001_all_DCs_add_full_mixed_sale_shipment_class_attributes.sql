-- SHIP-705
-- Add shipment class attributes for mixed sale and full sale

BEGIN;

insert into sos.shipment_class_attribute(name)
values
    ('Mixed Sale'),
    ('Full Sale');

COMMIT;
