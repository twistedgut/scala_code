--
-- CANDO-3055: Create INDEX on orders and shipment telephone number fields
-- on field stripped of non-numeric characters to enable better searching
-- on telephone numbers.
--

BEGIN WORK;

CREATE INDEX ON orders ( ( regexp_replace(telephone, '[^0-9]', '', 'g' ) ) );
CREATE INDEX ON orders ( ( regexp_replace(mobile_telephone, '[^0-9]', '', 'g' ) ) );
CREATE INDEX ON shipment ( ( regexp_replace(telephone, '[^0-9]', '', 'g' ) ) );
CREATE INDEX ON shipment ( ( regexp_replace(mobile_telephone, '[^0-9]', '', 'g' ) ) );

COMMIT WORK;
