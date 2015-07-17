BEGIN;

DROP FUNCTION product.mainstock_quantity_trigger();
DROP FUNCTION product.sample_quantity_trigger();

CREATE OR REPLACE FUNCTION mainstock_quantity_trigger() RETURNS trigger
    AS $$
    DECLARE
        -- Variables
        v_variant_id    INTEGER := NULL;
        v_quantity      INTEGER := NULL;
        v_product_id    INTEGER := NULL;
        v_channel_id    INTEGER := NULL;
        v_main_status_id INTEGER := NULL;
    BEGIN

        IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
            v_variant_id := NEW.variant_id;
        ELSE
            v_variant_id := OLD.variant_id;
        END IF;

        SELECT INTO v_main_status_id id
               FROM flow.status
               WHERE name = 'Main Stock'
                 AND type_id = ( SELECT id FROM flow.type WHERE name = 'Stock Status' );

        SELECT INTO v_product_id, v_quantity, v_channel_id v.product_id, sum( q.quantity ), q.channel_id
               FROM variant v, quantity q
               WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
           AND v.id = q.variant_id
           AND q.status_id = v_main_status_id
               GROUP by v.product_id, q.channel_id;

        UPDATE product.stock_summary SET main_stock = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        RETURN NEW;
    END;

    $$
    LANGUAGE plpgsql;


ALTER FUNCTION public.mainstock_quantity_trigger() OWNER TO www;

CREATE OR REPLACE FUNCTION sample_quantity_trigger() RETURNS trigger
    AS $$
    DECLARE
        -- Variables
        v_variant_id  INTEGER := NULL;
        v_quantity    INTEGER := NULL;
        v_product_id  INTEGER := NULL;
        v_channel_id  INTEGER := NULL;
        v_current     INTEGER := NULL;
        v_sample_status_id   INTEGER := NULL;
        v_creative_status_id INTEGER := NULL;
    BEGIN

        IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
            v_variant_id := NEW.variant_id;
        ELSE
            v_variant_id := OLD.variant_id;
        END IF;

        SELECT INTO v_sample_status_id id
               FROM flow.status
               WHERE name = 'Sample'
                 AND type_id = ( SELECT id FROM flow.type WHERE name = 'Stock Status' );

        SELECT INTO v_creative_status_id id
               FROM flow.status
               WHERE name = 'Creative'
                 AND type_id = ( SELECT id FROM flow.type WHERE name = 'Stock Status' );

        SELECT INTO v_product_id, v_quantity, v_channel_id v.product_id, sum( q.quantity ), q.channel_id
               FROM variant v, quantity q
               WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
           AND v.id = q.variant_id
           AND q.status_id IN (v_sample_status_id, v_creative_status_id)
               GROUP by v.product_id, q.channel_id;

        SELECT INTO v_current sample_stock FROM product.stock_summary WHERE product_id = v_product_id AND channel_id = v_channel_id;

        UPDATE product.stock_summary SET sample_stock = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        IF (v_quantity - v_current) = 1 THEN           
            UPDATE product.stock_summary SET sample_request = sample_request - 1, last_updated = current_timestamp WHERE sample_request > 0 AND product_id = v_product_id AND channel_id = v_channel_id;
        END IF;

        RETURN NEW;
    END;

    $$
    LANGUAGE plpgsql;


ALTER FUNCTION public.sample_quantity_trigger() OWNER TO www;

COMMIT;
