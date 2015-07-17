BEGIN;

ALTER TABLE product.stock_summary ADD COLUMN arrival_date DATE;



CREATE TABLE product.tmp (product_id, delivery_date, ship_date) as
(
SELECT
    p.id AS product_id,
    min(d.date) AS d_date,
    min(so.start_ship_date) AS so_start_ship_date
FROM stock_order so
   RIGHT JOIN stock_order_item soi ON soi.stock_order_id = so.id
   LEFT JOIN variant v ON v.id = soi.variant_id
   LEFT JOIN product p ON p.id = v.product_id
   LEFT JOIN link_delivery_item__stock_order_item link
        ON link.stock_order_item_id = soi.id
   JOIN delivery_item di ON di.id = link.delivery_item_id
   LEFT JOIN delivery d ON d.id = di.delivery_id
GROUP BY p.id
);



UPDATE product.stock_summary
SET arrival_date = (
    CASE WHEN product.tmp.delivery_date IS NOT NULL THEN delivery_date
    ELSE product.tmp.ship_date END)
FROM product.tmp
WHERE
    stock_summary.product_id = product.tmp.product_id;


DROP TABLE product.tmp;




CREATE OR REPLACE FUNCTION product.ship_date_trigger() RETURNS trigger AS '
DECLARE
    -- Variables
    v_delivery_date   DATE := NULL;
    v_ship_date       DATE := NULL;
    v_product_id      INTEGER := NULL;
    v_delivery_id     INTEGER := NULL;
BEGIN

--    stock_summary.product_id = product.tmp.product_id;

--    min(d.date) AS d_date,
--    min(so.start_ship_date) AS so_start_ship_date


    IF (TG_RELNAME = ''stock_order'') THEN
        IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
            v_product_id        := NEW.id;
        ELSE
            v_product_id        := OLD.id;
        END IF;
    ELSIF (TG_RELNAME = ''delivery'') THEN
        IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
            v_delivery_id        := NEW.id;
        ELSE
            v_delivery_id        := OLD.id;
        END IF;

        SELECT INTO v_product_id so.product_id
        FROM
            delivery d
            JOIN delivery_item di
                ON di.delivery_id = d.id
            JOIN link_delivery_item__stock_order_item link
                ON link.delivery_item_id = di.id
            JOIN stock_order_item soi
                ON soi.id = link.stock_order_item_id
            JOIN stock_order so
                ON so.id = soi.stock_order_id
        WHERE
            d.id = v_delivery_id;

    END IF;

    IF v_product_id IS NULL THEN
        RAISE NOTICE ''product.ship_data_trigger: cant get product_id'';
    END IF;
    

    SELECT INTO
        v_delivery_date, v_ship_date
        min(d.date), min(so.start_ship_date)
    FROM stock_order so
       RIGHT JOIN stock_order_item soi ON soi.stock_order_id = so.id
       LEFT JOIN variant v ON v.id = soi.variant_id
       LEFT JOIN product p ON p.id = v.product_id
       LEFT JOIN link_delivery_item__stock_order_item link
            ON link.stock_order_item_id = soi.id
       JOIN delivery_item di ON di.id = link.delivery_item_id
       LEFT JOIN delivery d ON d.id = di.delivery_id
    WHERE
        p.id = v_product_id
    GROUP BY p.id;


    UPDATE product.stock_summary
    SET
        arrival_date = (
        CASE WHEN v_delivery_date IS NOT NULL
            THEN v_delivery_date
        ELSE v_ship_date END)
    WHERE product_id = v_product_id;

    RETURN NEW;
END;
' LANGUAGE plpgsql;

CREATE TRIGGER arrival_date_tgr AFTER INSERT OR UPDATE OR DELETE
    ON public.delivery FOR EACH ROW
    EXECUTE PROCEDURE product.ship_date_trigger();

CREATE TRIGGER arrival_date_tgr AFTER INSERT OR UPDATE OR DELETE
    ON public.stock_order FOR EACH ROW
    EXECUTE PROCEDURE product.ship_date_trigger();


COMMIT;
