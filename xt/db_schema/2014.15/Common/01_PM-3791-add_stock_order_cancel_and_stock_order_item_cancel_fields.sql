-- PM-3791 - Add po_cancel field to stock orders and stock_order items
-- This field represents when a PO was cancelled, so that we can uncancel and
-- retain the original status of each of the stocks orders and the stock order items.
-- Target: xtracker, xtracker_dc2, xtdc3

BEGIN;

-- stock_order_cancel represents whether a stock order was cancelled from a PO.
ALTER TABLE stock_order
    ADD COLUMN stock_order_cancel BOOLEAN NOT NULL DEFAULT FALSE;

-- stock_order_item_cancel represents whether a sku was cancelled i.e set to 0 units.
ALTER TABLE stock_order_item
    ADD COLUMN stock_order_item_cancel BOOLEAN NOT NULL DEFAULT FALSE;

COMMIT;