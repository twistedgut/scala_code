
-- TP-684

BEGIN WORK;

ALTER TABLE ONLY public.product_attribute
	ALTER COLUMN description SET NOT NULL;
COMMIT WORK;

