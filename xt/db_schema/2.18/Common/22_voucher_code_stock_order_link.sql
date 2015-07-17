BEGIN;

  ALTER TABLE voucher.code RENAME COLUMN delivery_item_id TO stock_order_item_id;
  ALTER TABLE voucher.code ALTER stock_order_item_id SET NOT NULL;
COMMIT;
