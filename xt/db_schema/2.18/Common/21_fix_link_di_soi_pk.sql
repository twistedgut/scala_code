BEGIN;
    DELETE FROM link_delivery_item__stock_order_item WHERE stock_order_item_id IS NULL;
    ALTER TABLE link_delivery_item__stock_order_item ALTER stock_order_item_id SET NOT NULL;
    ALTER TABLE link_delivery_item__stock_order_item DROP CONSTRAINT link_delivery_item__stock_order_item_pkey;
    ALTER TABLE link_delivery_item__stock_order_item ADD PRIMARY KEY (delivery_item_id,stock_order_item_id);
COMMIT;
