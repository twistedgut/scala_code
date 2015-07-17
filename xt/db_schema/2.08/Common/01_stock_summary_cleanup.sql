-- Set some basic constraints and cleanup product.stock_summary

BEGIN;
    ALTER TABLE product.stock_summary ALTER COLUMN product_id SET NOT NULL;

    ALTER TABLE product.stock_summary DROP CONSTRAINT channel_id_for_key;
    ALTER TABLE product.stock_summary DROP CONSTRAINT product_id_for_key;
    ALTER TABLE product.stock_summary
        DROP CONSTRAINT stock_summary_channel_id_fkey;

    ALTER TABLE product.stock_summary
        ADD FOREIGN KEY ( channel_id ) REFERENCES channel(id) DEFERRABLE;
    ALTER TABLE product.stock_summary
        ADD FOREIGN KEY ( product_id ) REFERENCES product(id) DEFERRABLE;
COMMIT;
