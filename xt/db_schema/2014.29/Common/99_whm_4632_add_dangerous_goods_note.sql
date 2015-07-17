-- WHM-4632
-- Consume Dangerous Goods Note field from product update messages and store in
-- the shipping attributes table

BEGIN;

ALTER TABLE shipping_attribute ADD COLUMN dangerous_goods_note text;

COMMIT;
