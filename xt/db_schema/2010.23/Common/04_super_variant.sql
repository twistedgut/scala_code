BEGIN;
DROP VIEW super_variant;

CREATE OR REPLACE VIEW super_variant AS

SELECT
id,
product_id,
type_id,
size_id_old,
nap_size_id,
legacy_sku,
size_id,
designer_size_id,
std_size_id,
'product' as vtype
FROM variant 
UNION
SELECT
id,
voucher_product_id as product_id,
1 as type_id,
22 as size_id_old,
0 as nap_size_id,
cast(voucher_product_id as VARCHAR) || '-999' as legacy_sku,
999 as size_id,
0 as designer_size_id,
4 as std_size_id,
'voucher' as vtype
FROM 
voucher.variant;

GRANT SELECT ON super_variant to www;
COMMIT;
