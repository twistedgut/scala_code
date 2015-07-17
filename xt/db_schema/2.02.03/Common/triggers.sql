 BEGIN;   
    -- cancel pending stock quantity function and trigger
    CREATE OR REPLACE FUNCTION canc_adj_quantity_trigger() RETURNS
        trigger AS '
    DECLARE
        -- Variables
        v_shipment_item_id  INTEGER := NULL;
        v_quantity		    INTEGER := NULL;
        v_product_id	    INTEGER := NULL;
        v_channel_id	    INTEGER := NULL;
        channels            RECORD;
    BEGIN

        IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
            v_shipment_item_id        := NEW.shipment_item_id;
        ELSE
            v_shipment_item_id        := OLD.shipment_item_id;
        END IF;

        FOR channels IN SELECT id FROM channel LOOP

            v_channel_id = channels.id;

            SELECT INTO v_product_id v.product_id 
               FROM variant v, shipment_item si
               WHERE si.id = v_shipment_item_id
               AND si.variant_id = v.id;

            SELECT INTO v_quantity count( si.* )
               FROM variant v, cancelled_item ci, shipment_item si, link_orders__shipment los, orders o
               WHERE v.product_id = (SELECT product_id FROM variant WHERE id = (SELECT variant_id FROM shipment_item WHERE id = v_shipment_item_id))
               AND v.id = si.variant_id
               AND si.shipment_item_status_id = 10
               AND si.id = ci.shipment_item_id
               AND ci.adjusted = 0
               AND si.shipment_id = los.shipment_id
               AND los.orders_id = o.id
               AND o.channel_id = v_channel_id
               GROUP by v.product_id;

            IF v_quantity IS NULL THEN
                    v_quantity = 0;
            END IF;

            RAISE NOTICE ''CID: % ; PID: % ; QTY: %'', v_channel_id, v_product_id, v_quantity;

            UPDATE product.stock_summary SET cancel_pending = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id; 
            
        END LOOP;    

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    -- sample stock quantity function and trigger
    CREATE OR REPLACE FUNCTION sample_quantity_trigger() RETURNS
        trigger AS '
    DECLARE
        -- Variables
        v_variant_id	 INTEGER := NULL;
        v_quantity		 INTEGER := NULL;
        v_product_id	 INTEGER := NULL;
        v_channel_id	 INTEGER := NULL;
        v_current	     INTEGER := NULL;
    BEGIN

        IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
            v_variant_id        := NEW.variant_id;
        ELSE
            v_variant_id        := OLD.variant_id;
        END IF;

        SELECT INTO v_product_id, v_quantity, v_channel_id v.product_id, sum( q.quantity ), q.channel_id
               FROM variant v, quantity q
               WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
           AND v.id = q.variant_id
           AND q.location_id IN ( select id from location where type_id in (4, 6) )
               GROUP by v.product_id, q.channel_id;

        SELECT INTO v_current sample_stock FROM product.stock_summary WHERE product_id = v_product_id AND channel_id = v_channel_id;

        UPDATE product.stock_summary SET sample_stock = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        IF (v_quantity - v_current) = 1 THEN           
            UPDATE product.stock_summary SET sample_request = sample_request - 1, last_updated = current_timestamp WHERE sample_request > 0 AND product_id = v_product_id AND channel_id = v_channel_id;
        END IF;

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    -- fix old sample request data
    UPDATE product.stock_summary SET sample_request = 0, last_updated = current_timestamp WHERE sample_request > 0;

COMMIT;