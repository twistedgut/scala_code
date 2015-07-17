-- Clean up product.stock_summary constraints

BEGIN;
    ALTER TABLE product.stock_summary ADD PRIMARY KEY (product_id, channel_id);
    ALTER TABLE product.stock_summary DROP CONSTRAINT prod_channel;
COMMIT;
