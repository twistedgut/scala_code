-- Add 'show_sale_products' column to 'business' table

BEGIN WORK;

ALTER TABLE business ADD COLUMN "show_sale_products" boolean;
UPDATE business
	SET show_sale_products = false
;
ALTER TABLE business ALTER COLUMN  "show_sale_products" SET NOT NULL;
UPDATE business
	SET show_sale_products = true
WHERE config_section = 'OUTNET'
;

COMMIT WORK;
