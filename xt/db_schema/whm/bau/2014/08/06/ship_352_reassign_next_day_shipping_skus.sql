-- SHIP-352
-- DC1 - update MRP next-day shipping skus

BEGIN;

update shipping_charge
set sku = '910003' || substring(sku from '....$')
where sku in

('9000421-002',
'9000421-003',
'9000421-004',
'9000421-005',
'9000421-006',
'9000421-007',
'9000421-008');

COMMIT;
