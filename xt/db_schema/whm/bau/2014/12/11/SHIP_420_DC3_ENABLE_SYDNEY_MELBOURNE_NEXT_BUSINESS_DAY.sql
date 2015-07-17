-- DCOP-1507 (part of SHIP-420)
-- DC3 - enable Sydney Next Business Day shipping sku

BEGIN;

update shipping_charge set is_enabled = 't' where sku = '9000330-001';

COMMIT;
