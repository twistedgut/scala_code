BEGIN;

CREATE OR REPLACE FUNCTION ordered_quantity_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_variant_id	INTEGER := NULL;
    v_ordered_quantity	INTEGER := NULL;
    v_product_id	INTEGER := NULL;
    v_channel_id	INTEGER := NULL;
BEGIN

    IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
        v_variant_id        := NEW.variant_id;
    ELSE
        v_variant_id        := OLD.variant_id;
    END IF;

    SELECT INTO v_product_id
                v.product_id
    FROM variant v
    WHERE v.id = v_variant_id;

    SELECT INTO v_channel_id,  v_ordered_quantity
                po.channel_id, sum( CASE soi.cancel WHEN false THEN soi.quantity ELSE 0 END )
    FROM variant v
    JOIN stock_order_item soi ON soi.variant_id = v.id
    JOIN stock_order so ON so.id = soi.stock_order_id
    JOIN purchase_order po ON po.id = so.purchase_order_id
    WHERE v.product_id = v_product_id
      AND v.type_id = 1
    GROUP BY po.channel_id;

    UPDATE product.stock_summary
    SET ordered = v_ordered_quantity,
        last_updated = current_timestamp
    WHERE product_id = v_product_id
      AND channel_id = v_channel_id;

    RETURN NEW;
END;

' LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delivered_quantity_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_delivery_item_id	 INTEGER := NULL;
    v_delivered_quantity INTEGER := NULL;
    v_product_id	 INTEGER := NULL;
    v_channel_id	INTEGER := NULL;
BEGIN

    IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
        v_delivery_item_id        := NEW.id;
    ELSE
        v_delivery_item_id        := OLD.id;
    END IF;

    SELECT INTO v_product_id
                v.product_id
    FROM delivery_item di
    JOIN link_delivery_item__stock_order_item lk ON lk.delivery_item_id = di.id
    JOIN stock_order_item soi ON soi.id = lk.stock_order_item_id
    JOIN variant v ON v.id = soi.variant_id
    WHERE di.id = v_delivery_item_id
    GROUP BY v.product_id;

    SELECT INTO v_channel_id,  v_delivered_quantity
                po.channel_id, sum( CASE di.cancel WHEN false THEN di.quantity ELSE 0 END )
    FROM variant v
    JOIN stock_order_item soi ON soi.variant_id = v.id
    JOIN stock_order so ON so.id = soi.stock_order_id
    JOIN purchase_order po ON po.id = so.purchase_order_id
    JOIN link_delivery_item__stock_order_item lk ON lk.stock_order_item_id = soi.id
    JOIN delivery_item di ON di.id = lk.delivery_item_id
    WHERE v.product_id = v_product_id
      AND v.type_id = 1
    GROUP BY po.channel_id;

    UPDATE product.stock_summary
    SET delivered = v_delivered_quantity,
        last_updated = current_timestamp
    WHERE product_id = v_product_id
      AND channel_id = v_channel_id;

    RETURN NEW;
END;

' LANGUAGE plpgsql;

COMMIT;
