-- Remove unnecessary adjusted column

BEGIN;

    -- Drop unnecessary trigger and function
    DROP TRIGGER IF EXISTS canc_qty_tgr ON shipment_item;
    DROP FUNCTION IF EXISTS canc_pending_quantity_trigger();

    -- Drop the redundant column and set a default for date
    ALTER TABLE cancelled_item
        DROP adjusted,
        ALTER date SET DEFAULT now();

    -- Replace the function and create a trigger on shipment_item to run it
    CREATE OR REPLACE FUNCTION canc_adj_quantity_trigger() RETURNS TRIGGER AS
$BODY$
DECLARE
    v_shipment_item_id      INTEGER;
    v_do_update             BOOL;
    v_quantity              INTEGER;
    v_product_id            INTEGER;
    v_channel_id            INTEGER;
    v_status_cancel_pending INTEGER;
    channel_row             RECORD;
    BEGIN

        SELECT id INTO v_status_cancel_pending FROM shipment_item_status WHERE status = 'Cancel Pending';

        IF (TG_OP = 'INSERT') THEN
            v_shipment_item_id := NEW.id;
            v_do_update        := NEW.shipment_item_status_id = v_status_cancel_pending;
        ELSIF (TG_OP = 'UPDATE') THEN
            v_shipment_item_id := NEW.id;
            v_do_update        := NEW.shipment_item_status_id = v_status_cancel_pending
                               OR OLD.shipment_item_status_id = v_status_cancel_pending;
        ELSE
            v_shipment_item_id := OLD.id;
            v_do_update        := OLD.shipment_item_status_id = v_status_cancel_pending;
        END IF;

        -- We only update the cancel_pending column in the stock_summary table
        -- if we move from/to the 'Cancel Pending' status
        IF (NOT v_do_update) THEN
            RETURN NEW;
        END IF;

        -- We need to loop so we set the cnacel_pending quantity to 0 on all
        -- channel_row the item is not sold on
        FOR channel_row IN SELECT id FROM channel LOOP

            v_channel_id = channel_row.id;

            -- Get the product_id (notice if we did this in the second
            -- query we'd get null for other channels)
            SELECT INTO v_product_id v.product_id
            FROM variant v, shipment_item si
            WHERE si.id = v_shipment_item_id
            AND si.variant_id = v.id;

            -- Get the quantity for cancel pending items on the given
            -- channel
            SELECT INTO v_quantity count( si.* )
            FROM shipment_item si
            JOIN variant v ON si.variant_id = v.id
            JOIN link_orders__shipment los ON si.shipment_id = los.shipment_id
            JOIN orders o ON los.orders_id = o.id
            WHERE v.product_id = (SELECT product_id FROM variant WHERE id = (SELECT variant_id FROM shipment_item WHERE id = v_shipment_item_id))
            AND si.shipment_item_status_id = v_status_cancel_pending
            AND o.channel_id = v_channel_id
            GROUP by v.product_id;

            -- Default to 0 if we don't get anything from the previous
            -- query
            IF v_quantity IS NULL THEN
                v_quantity = 0;
            END IF;

            -- Update the stock summary table
            UPDATE product.stock_summary SET cancel_pending = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        END LOOP;

        RETURN NEW;
    END;
$BODY$
LANGUAGE plpgsql;

    -- Replace the trigger
    DROP TRIGGER IF EXISTS canc_adj_tgr ON cancelled_item;
    CREATE TRIGGER canc_adj_tgr AFTER INSERT OR UPDATE OR DELETE ON shipment_item FOR EACH ROW EXECUTE PROCEDURE canc_adj_quantity_trigger();
COMMIT;
