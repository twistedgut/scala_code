-- Purpose:
--  Create/Amend tables for stock summary stuff

BEGIN;

-- create product stock summary table

create table product.stock_summary (product_id, ordered, delivered, main_stock, sample_stock, sample_request, reserved, pre_pick, cancel_pending, last_updated) as
       (select id as product_id, 0, 0, 0, 0, 0, 0, 0, 0, current_timestamp from product);

grant all on product.stock_summary to www;



-- populate main_stock quantity

CREATE TABLE product.tmp_qty (product_id, quantity) as
       (SELECT v.product_id, sum( q.quantity )
	FROM variant v, quantity q
	WHERE v.type_id = 1
	AND v.id = q.variant_id
	AND q.location_id not in ( select id from location where type_id <> 1 )
	GROUP BY v.product_id);

UPDATE product.stock_summary
SET main_stock = tmp_qty.quantity
FROM product.tmp_qty
WHERE stock_summary.product_id = tmp_qty.product_id;

DROP TABLE product.tmp_qty;


-- populate ordered quantity

CREATE TABLE product.tmp_qty (product_id, quantity) as
       (SELECT v.product_id, sum( soi.quantity )
	FROM variant v, stock_order_item soi
	WHERE v.type_id = 1
	AND v.id = soi.variant_id
	   AND soi.cancel = false
	GROUP BY v.product_id);

UPDATE product.stock_summary
SET ordered = tmp_qty.quantity
FROM product.tmp_qty
WHERE stock_summary.product_id = tmp_qty.product_id;

DROP TABLE product.tmp_qty;


-- populate delivered quantity

CREATE TABLE product.tmp_qty (product_id, quantity) as
       (SELECT v.product_id, sum( di.quantity )
           FROM variant v, stock_order_item soi, link_delivery_item__stock_order_item lk, delivery_item di
           WHERE v.type_id = 1
	   AND v.id = soi.variant_id
	   AND soi.id = lk.stock_order_item_id
	   AND lk.delivery_item_id = di.id
	   AND di.cancel = false
           GROUP BY v.product_id);

UPDATE product.stock_summary
SET delivered = tmp_qty.quantity
FROM product.tmp_qty
WHERE stock_summary.product_id = tmp_qty.product_id;

DROP TABLE product.tmp_qty;


-- populate sample quantity

CREATE TABLE product.tmp_qty (product_id, quantity) as
       (SELECT v.product_id, sum( q.quantity )
           FROM variant v, quantity q
           WHERE v.id = q.variant_id
	   AND q.location_id IN ( select id from location where type_id in (4, 6) )
           GROUP by v.product_id);

UPDATE product.stock_summary
SET sample_stock = tmp_qty.quantity
FROM product.tmp_qty
WHERE stock_summary.product_id = tmp_qty.product_id;

DROP TABLE product.tmp_qty;


-- populate sample request

CREATE TABLE product.tmp_qty (product_id, quantity) as
       (SELECT v.product_id, count(st.*)
           FROM variant v, stock_transfer st
           WHERE v.type_id = 1
	   AND v.id = st.variant_id
	   AND st.status_id = 1
	   AND st.type_id != 2
           GROUP by v.product_id);

UPDATE product.stock_summary
SET sample_request = tmp_qty.quantity
FROM product.tmp_qty
WHERE stock_summary.product_id = tmp_qty.product_id;

DROP TABLE product.tmp_qty;


-- populate reserved quantity

CREATE TABLE product.tmp_qty (product_id, quantity) as
       (SELECT v.product_id, count( r.* )
           FROM variant v, reservation r
           WHERE v.type_id = 1
	   AND v.id = r.variant_id
           AND r.status_id = 2
           GROUP BY v.product_id);

UPDATE product.stock_summary
SET reserved = tmp_qty.quantity
FROM product.tmp_qty
WHERE stock_summary.product_id = tmp_qty.product_id;

DROP TABLE product.tmp_qty;


-- populate pre-pick quantity

CREATE TABLE product.tmp_qty (product_id, quantity) as
       (SELECT v.product_id, count( si.* )
           FROM variant v, shipment_item si
           WHERE v.type_id = 1
           AND v.id = si.variant_id
	   AND si.shipment_item_status_id < 3
           GROUP by v.product_id);

UPDATE product.stock_summary
SET pre_pick = tmp_qty.quantity
FROM product.tmp_qty
WHERE stock_summary.product_id = tmp_qty.product_id;

DROP TABLE product.tmp_qty;


-- populate cancel_pending quantity

CREATE TABLE product.tmp_qty (product_id, quantity) as
       (SELECT v.product_id, count( si.* )
           FROM variant v, cancelled_item ci, shipment_item si
           WHERE v.type_id = 1
           AND v.id = si.variant_id
	   AND si.shipment_item_status_id = 10
	   AND si.id = ci.shipment_item_id
           AND ci.adjusted = 0
           GROUP by v.product_id);

UPDATE product.stock_summary
SET cancel_pending = tmp_qty.quantity
FROM product.tmp_qty
WHERE stock_summary.product_id = tmp_qty.product_id;

DROP TABLE product.tmp_qty;





-- ordered quantity function and trigger

CREATE OR REPLACE FUNCTION product.ordered_quantity_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_variant_id	INTEGER := NULL;
    v_ordered_quantity	INTEGER := NULL;
    v_product_id	INTEGER := NULL;
BEGIN

	IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
		v_variant_id        := NEW.variant_id;
	ELSE
		v_variant_id        := OLD.variant_id;
	END IF;

	SELECT INTO v_product_id, v_ordered_quantity v.product_id, sum( soi.quantity )
	FROM variant v, stock_order_item soi
	WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
	   AND v.id = soi.variant_id
	   AND v.type_id = 1
	   AND soi.cancel = false
	GROUP BY v.product_id;


	UPDATE product.stock_summary SET ordered = v_ordered_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;

	RETURN NEW;
END;

' LANGUAGE plpgsql;

CREATE TRIGGER ord_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON stock_order_item FOR EACH ROW EXECUTE PROCEDURE product.ordered_quantity_trigger();



-- delivered quantity function and trigger

CREATE OR REPLACE FUNCTION product.delivered_quantity_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_delivery_item_id	 INTEGER := NULL;
    v_delivered_quantity INTEGER := NULL;
    v_product_id	 INTEGER := NULL;
BEGIN

	IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
		v_delivery_item_id        := NEW.id;
	ELSE
		v_delivery_item_id        := OLD.id;
	END IF;

	SELECT INTO v_product_id, v_delivered_quantity v.product_id, sum( di.quantity )
           FROM variant v, stock_order_item soi, link_delivery_item__stock_order_item lk, delivery_item di
           WHERE v.product_id = (SELECT product_id FROM stock_order WHERE id IN (SELECT stock_order_id from link_delivery__stock_order WHERE delivery_id = (SELECT delivery_id FROM delivery_item WHERE id = v_delivery_item_id)))
	   AND v.id = soi.variant_id
	   AND v.type_id = 1
	   AND soi.id = lk.stock_order_item_id
	   AND lk.delivery_item_id = di.id
	   AND di.cancel = false
           GROUP BY v.product_id;

	UPDATE product.stock_summary SET delivered = v_delivered_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;

	RETURN NEW;
END;

' LANGUAGE plpgsql;

CREATE TRIGGER del_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON delivery_item FOR EACH ROW EXECUTE PROCEDURE product.delivered_quantity_trigger();



-- main stock quantity function and trigger

CREATE OR REPLACE FUNCTION product.mainstock_quantity_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_variant_id	 INTEGER := NULL;
    v_quantity		 INTEGER := NULL;
    v_product_id	 INTEGER := NULL;
BEGIN

	IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
		v_variant_id        := NEW.variant_id;
	ELSE
		v_variant_id        := OLD.variant_id;
	END IF;

	SELECT INTO v_product_id, v_quantity v.product_id, sum( q.quantity )
           FROM variant v, quantity q
           WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
	   AND v.id = q.variant_id
	   AND q.location_id IN ( select id from location where type_id = 1 )
           GROUP by v.product_id;

	UPDATE product.stock_summary SET main_stock = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;

	RETURN NEW;
END;

' LANGUAGE plpgsql;

CREATE TRIGGER main_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON quantity FOR EACH ROW EXECUTE PROCEDURE product.mainstock_quantity_trigger();



-- sample stock quantity function and trigger

CREATE OR REPLACE FUNCTION product.sample_quantity_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_variant_id	 INTEGER := NULL;
    v_quantity		 INTEGER := NULL;
    v_product_id	 INTEGER := NULL;
BEGIN

	IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
		v_variant_id        := NEW.variant_id;
	ELSE
		v_variant_id        := OLD.variant_id;
	END IF;

	SELECT INTO v_product_id, v_quantity v.product_id, sum( q.quantity )
           FROM variant v, quantity q
           WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
	   AND v.id = q.variant_id
	   AND q.location_id IN ( select id from location where type_id in (4, 6) )
           GROUP by v.product_id;

	UPDATE product.stock_summary SET sample_stock = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;

	RETURN NEW;
END;

' LANGUAGE plpgsql;

CREATE TRIGGER sample_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON quantity FOR EACH ROW EXECUTE PROCEDURE product.sample_quantity_trigger();


-- sample request quantity function and trigger

CREATE OR REPLACE FUNCTION product.sample_request_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_variant_id	 INTEGER := NULL;
    v_quantity		 INTEGER := NULL;
    v_product_id	 INTEGER := NULL;
BEGIN

	IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
		v_variant_id        := NEW.variant_id;
	ELSE
		v_variant_id        := OLD.variant_id;
	END IF;

	SELECT INTO v_product_id, v_quantity v.product_id, count(st.*)
           FROM variant v, stock_transfer st
           WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
	   AND v.id = st.variant_id
	   AND st.status_id = 1
	   AND st.type_id != 2
           GROUP by v.product_id;

	UPDATE product.stock_summary SET sample_request = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;

	RETURN NEW;
END;

' LANGUAGE plpgsql;

CREATE TRIGGER sample_req_tgr AFTER INSERT OR UPDATE OR DELETE ON stock_transfer FOR EACH ROW EXECUTE PROCEDURE product.sample_request_trigger();



-- reserved stock quantity function and trigger

CREATE OR REPLACE FUNCTION product.reserved_quantity_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_variant_id	 INTEGER := NULL;
    v_quantity		 INTEGER := NULL;
    v_product_id	 INTEGER := NULL;
BEGIN

	IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
		v_variant_id        := NEW.variant_id;
	ELSE
		v_variant_id        := OLD.variant_id;
	END IF;

	SELECT INTO v_product_id, v_quantity v.product_id, count( r.* )
           FROM variant v LEFT JOIN reservation r ON v.id = r.variant_id AND r.status_id = 2 
           WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
           GROUP BY v.product_id;

	UPDATE product.stock_summary SET reserved = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;

	RETURN NEW;
END;

' LANGUAGE plpgsql;

CREATE TRIGGER reserved_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON reservation FOR EACH ROW EXECUTE PROCEDURE product.reserved_quantity_trigger();




-- pre-pick stock quantity function and trigger

CREATE OR REPLACE FUNCTION product.prepick_quantity_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_variant_id	 INTEGER := NULL;
    v_quantity		 INTEGER := NULL;
    v_product_id	 INTEGER := NULL;
BEGIN

	IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
		v_variant_id        := NEW.variant_id;
	ELSE
		v_variant_id        := OLD.variant_id;
	END IF;

	SELECT INTO v_product_id, v_quantity v.product_id, count( si.* )
           FROM variant v LEFT JOIN shipment_item si ON v.id = si.variant_id AND si.shipment_item_status_id < 3
	   WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
           GROUP BY v.product_id;

	IF v_quantity IS NULL THEN
		v_quantity := 0;
	END IF;

	UPDATE product.stock_summary SET pre_pick = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;

	RETURN NEW;
END;

' LANGUAGE plpgsql;

CREATE TRIGGER prepick_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON shipment_item FOR EACH ROW EXECUTE PROCEDURE product.prepick_quantity_trigger();



-- cancel pending stock quantity function and trigger

CREATE OR REPLACE FUNCTION product.canc_pending_quantity_trigger() RETURNS
    trigger AS '
DECLARE
    -- Variables
    v_shipment_item_id	 INTEGER := NULL;
    v_old_status_id	 INTEGER := NULL;
    v_new_status_id	 INTEGER := NULL;
    v_quantity		 INTEGER := NULL;
    v_product_id	 INTEGER := NULL;
BEGIN

	IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
		v_shipment_item_id        := NEW.id;
	ELSE
		v_shipment_item_id        := OLD.id;
	END IF;

	IF (TG_OP = ''INSERT'') THEN
		v_old_status_id		  := NEW.shipment_item_status_id;
		v_new_status_id		  := NEW.shipment_item_status_id;
	ELSIF (TG_OP = ''UPDATE'') THEN
		v_old_status_id		  := OLD.shipment_item_status_id;
		v_new_status_id		  := NEW.shipment_item_status_id;
	ELSE
		v_old_status_id		  := OLD.shipment_item_status_id;
		v_new_status_id		  := OLD.shipment_item_status_id;
	END IF;

	IF (v_old_status_id = 10 OR v_new_status_id = 10) THEN

		SELECT INTO v_product_id, v_quantity v.product_id, count( si.* )
		   FROM variant v, cancelled_item ci, shipment_item si
		   WHERE v.product_id = (SELECT product_id FROM variant WHERE id = (SELECT variant_id FROM shipment_item WHERE id = v_shipment_item_id))
		   AND v.id = si.variant_id
		   AND si.shipment_item_status_id = 10
		   AND si.id = ci.shipment_item_id
		   AND ci.adjusted = 0
		   GROUP by v.product_id;

		UPDATE product.stock_summary SET cancel_pending = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;

	END IF;

	RETURN NEW;
END;

' LANGUAGE plpgsql;

CREATE TRIGGER canc_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON shipment_item FOR EACH ROW EXECUTE PROCEDURE product.canc_pending_quantity_trigger();



-- create foreign product stock summary table

create table product.stock_summary_foreign (product_id, ordered, delivered, main_stock, sample_stock, sample_request, reserved, pre_pick, cancel_pending, last_updated) as
       (select id as product_id, 0, 0, 0, 0, 0, 0, 0, 0, current_timestamp from product);

grant all on product.stock_summary_foreign to www;










create index pss_product_id on product.stock_summary(product_id);
create index pssf_product_id on product.stock_summary_foreign(product_id);

COMMIT;
