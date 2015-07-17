BEGIN;
CREATE OR REPLACE VIEW super_variant AS

SELECT
id,
type_id,
product_id,
'product' as vtype
FROM variant 
UNION
SELECT
id,
1 as type_id,
voucher_product_id as product_id,
'voucher' as vtype
FROM 
voucher.variant;

GRANT SELECT ON super_variant to www;
COMMIT;
