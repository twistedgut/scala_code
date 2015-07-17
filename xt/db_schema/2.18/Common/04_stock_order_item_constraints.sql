BEGIN;
    -- Disable trigger while placing data in a consistent state
    ALTER TABLE stock_order_item DISABLE TRIGGER ord_qty_tgr;
    ALTER TABLE stock_order_item ALTER COLUMN stock_order_id SET NOT NULL;
    ALTER TABLE stock_order_item ALTER COLUMN status_id SET NOT NULL;

    -- Set stock_order_item(type_id) to 'Unknown' or 'Sample', depending on stock_order(type_id)
    UPDATE stock_order_item soi SET type_id = CASE
        WHEN ( SELECT type_id FROM stock_order so WHERE soi.stock_order_id = so.id ) = ( SELECT id FROM stock_order_type WHERE type='Sample' )
            THEN ( SELECT id FROM stock_order_item_type WHERE type='Sample' )
        ELSE ( SELECT id FROM stock_order_item_type WHERE type='Unknown' )
        END
        WHERE soi.type_id IS NULL;
    ;

    ALTER TABLE stock_order_item ALTER COLUMN type_id SET NOT NULL;

    -- Set all stock_order_item(cancel) to false where they're unknown
    UPDATE stock_order_item SET cancel=false WHERE cancel IS NULL;
    ALTER TABLE stock_order_item ALTER COLUMN cancel SET DEFAULT false;
    ALTER TABLE stock_order_item ALTER COLUMN cancel SET NOT NULL;

    -- Re-enable trigger
    ALTER TABLE stock_order_item ENABLE TRIGGER ord_qty_tgr;
COMMIT;
