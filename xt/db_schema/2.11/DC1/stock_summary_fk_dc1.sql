-- Drop orphan rows
-- Add a foreign key between stock summary and product_channel

BEGIN;
    DELETE FROM product.stock_summary WHERE channel_id = 3 AND product_id IN (34262);
    ALTER TABLE product.stock_summary
        ADD CONSTRAINT stock_summary_product_id_channel_id_fkey FOREIGN KEY (product_id,channel_id) REFERENCES product_channel(product_id,channel_id);
COMMIT;
