BEGIN;
    ALTER TABLE voucher.code
        DROP CONSTRAINT code_delivery_item_id_fkey,
        ADD FOREIGN KEY (stock_order_item_id) REFERENCES stock_order_item(id),
        ALTER COLUMN stock_order_item_id DROP NOT NULL
    ;
COMMIT;
