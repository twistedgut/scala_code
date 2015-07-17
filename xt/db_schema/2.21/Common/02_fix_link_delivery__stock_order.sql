BEGIN;
    DELETE FROM link_delivery__stock_order WHERE stock_order_id IS NULL;
    ALTER TABLE link_delivery__stock_order ALTER COLUMN stock_order_id SET NOT NULL;
COMMIT;
