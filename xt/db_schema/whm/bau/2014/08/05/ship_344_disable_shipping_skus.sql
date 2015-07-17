-- SHIP-344
-- DC2 disable shipping SKUs 9000207-001 and 9000208-001

BEGIN;

update shipping_charge
set is_enabled = 'f'
where sku in('9000207-001', '9000208-001');

COMMIT;
