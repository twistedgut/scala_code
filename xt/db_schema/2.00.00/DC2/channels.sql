-- create channel lookup and add field to relevant tables
-- orders
-- purchase_order
-- product
-- logs?
-- sample request/cart

BEGIN;

    -- DROP STOCK SUMMARY TRIGGERS BEFORE WE START
    DROP TRIGGER ord_qty_tgr ON stock_order_item;
    DROP TRIGGER del_qty_tgr ON delivery_item;
    DROP TRIGGER main_qty_tgr ON quantity;
    DROP TRIGGER sample_qty_tgr ON quantity;
    DROP TRIGGER sample_req_tgr ON stock_transfer;
    DROP TRIGGER reserved_qty_tgr ON reservation;
    DROP TRIGGER arrival_date_tgr ON delivery;
    DROP TRIGGER prepick_qty_tgr ON shipment_item;
    DROP TRIGGER canc_qty_tgr ON shipment_item;

    -- new table to hold business
    CREATE TABLE public.business (
        id          serial primary key,
        name        text not null,
        config_section varchar(255) not null,
        url varchar(255) not null,
        UNIQUE(name)
    );

    GRANT ALL ON public.business TO www;
    GRANT ALL ON public.business_id_seq TO www;

    -- some data for public.business
    INSERT INTO public.business (name, config_section, url) VALUES
        ('NET-A-PORTER', 'NAP', 'www.net-a-porter.com');
    INSERT INTO public.business (name, config_section, url) VALUES
        ('The Outnet', 'OUTNET', 'www.theoutnet.com');

    -- new table to hold distribution centre
    CREATE TABLE public.distrib_centre (
        id          serial primary key,
        name        text not null,
        UNIQUE(name)
    );

    GRANT ALL ON public.distrib_centre TO www;
    GRANT ALL ON public.distrib_centre_id_seq TO www;

    -- some data for public.distrib_centre
    INSERT INTO public.distrib_centre (name) VALUES
        ('DC1');
    INSERT INTO public.distrib_centre (name) VALUES
        ('DC2');
    

    -- new table for channel
    CREATE TABLE public.channel (
        id          serial primary key,
        name        text not null,
        business_id integer references public.business(id) not null,
        distrib_centre_id integer references public.distrib_centre(id) not null,
        UNIQUE(name)
    );

    GRANT ALL ON public.channel TO www;
    GRANT ALL ON public.channel_id_seq TO www;
    
    -- NAP AM
    INSERT INTO public.channel (id, name, business_id, distrib_centre_id) VALUES
        (2, 'NET-A-PORTER', 1, 2);

    -- OUTNET AM
    INSERT INTO public.channel (id, name, business_id, distrib_centre_id) VALUES
       (4, 'The Outnet', 2, 2);




    -- ORDER CHANNELISATION


    -- orders table
    -- first drop view which relies on existing channel_id field
    DROP VIEW public.njiv_first_orders;
    ALTER TABLE orders DROP COLUMN channel_id;
    DROP TABLE order_channel;

    ALTER TABLE orders ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    ALTER TABLE orders ADD COLUMN ip_address varchar(100) NULL;
    ALTER TABLE orders ADD COLUMN placed_by varchar(200) NULL;
    UPDATE orders SET channel_id = 2;
    ALTER TABLE orders ALTER COLUMN channel_id SET NOT NULL;

    -- re-create view we had to drop
    CREATE VIEW njiv_first_orders AS
    SELECT orders.id, orders.order_nr, orders.basket_nr, orders.invoice_nr, orders.session_id, orders.cookie_id, orders.date, orders.total_value, orders.gift_credit, orders.store_credit, orders.customer_id, orders.invoice_address_id, orders.credit_rating, orders.card_issuer, orders.card_scheme, orders.card_country, orders.card_hash, orders.cv2_response, orders.order_status_id, orders.email, orders.telephone, orders.mobile_telephone, orders."comment", orders.currency_id, orders.channel_id FROM orders, (SELECT orders.customer_id, min(orders.date) AS minorderdate FROM orders GROUP BY orders.customer_id) firstorder WHERE ((orders.customer_id = firstorder.customer_id) AND (orders.date = firstorder.minorderdate));
    ALTER TABLE public.njiv_first_orders OWNER TO postgres;


    -- new finance flag
    INSERT INTO flag VALUES (102, 'Possible Fraud', 3);



    -- PRODUCT CHANNELISATION

    -- channel transfer status lookup
    CREATE TABLE public.channel_transfer_status (
        id          serial primary key,
        status      varchar(100) not null unique
    );

    GRANT ALL ON public.channel_transfer_status TO www;
    GRANT ALL ON public.channel_transfer_status_id_seq TO www;

    INSERT INTO public.channel_transfer_status (status) VALUES ('None');
    INSERT INTO public.channel_transfer_status (status) VALUES ('Requested');
    INSERT INTO public.channel_transfer_status (status) VALUES ('In Progress');
    INSERT INTO public.channel_transfer_status (status) VALUES ('Transferred');

    -- product_channel table
    CREATE TABLE public.product_channel (
        id          serial primary key,
        product_id  integer references public.product(id) not null,
        channel_id  integer references public.channel(id) not null,
        live        boolean not null default false,
        staging     boolean not null default false,
        visible     boolean not null default false,
        disable_update  boolean not null default false,
        cancelled   boolean not null default false,
        arrival_date timestamp null,
        upload_date timestamp null,
        transfer_status_id integer references public.channel_transfer_status(id) not null default 1,
        transfer_date timestamp null,
        UNIQUE(product_id, channel_id)
    );

    GRANT ALL ON public.product_channel TO www;
    GRANT ALL ON public.product_channel_id_seq TO www;

    -- populate table
    INSERT INTO public.product_channel (product_id, channel_id, live, staging, visible, disable_update, upload_date, transfer_status_id )
    SELECT p.id, 2, p.live, p.staging, p.visible, p.disableupdate, upload.upload_date, 1
    FROM product p left join upload_product up on p.id = up.product_id left join upload on up.upload_id = upload.id;

    -- set cancelled status
    UPDATE public.product_channel SET cancelled = true
    WHERE product_id in (select product_id from stock_order where type_id = 1 and cancel = true)
    AND product_id not in (select product_id from stock_order where type_id = 1 and cancel = false);

    -- set arrival date
    UPDATE public.product_channel SET arrival_date = (select min(del.date) from stock_order so, link_delivery__stock_order link, delivery del where so.id = link.stock_order_id and link.delivery_id = del.id and so.type_id = 1 and so.product_id = public.product_channel.product_id)
    WHERE product_id in (select product_id from stock_order where type_id = 1);



    -- PURCHASE ORDER CHANNELISATION

    -- purchase order table
    ALTER TABLE purchase_order ADD COLUMN channel_id integer REFERENCES public.channel(id);
    UPDATE purchase_order SET channel_id = 2;
    ALTER TABLE purchase_order ALTER COLUMN channel_id SET NOT NULL;


    -- CUSTOMER CHANNELISATION
    ALTER TABLE customer ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE customer SET channel_id = 2;
    ALTER TABLE customer ALTER COLUMN channel_id SET NOT NULL;

    -- STORE CREDIT CHANNELISATION
    ALTER TABLE customer_credit ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE customer_credit SET channel_id = 2;
    ALTER TABLE customer_credit ALTER COLUMN channel_id SET NOT NULL;


    -- LOG CHANNELISATION
    ALTER TABLE log_stock ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE log_stock SET channel_id = 2;
    ALTER TABLE log_stock ALTER COLUMN channel_id SET NOT NULL;

    ALTER TABLE log_rtv_stock ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE log_rtv_stock SET channel_id = 2;
    ALTER TABLE log_rtv_stock ALTER COLUMN channel_id SET NOT NULL;

    ALTER TABLE log_pws_stock ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE log_pws_stock SET channel_id = 2;
    ALTER TABLE log_pws_stock ALTER COLUMN channel_id SET NOT NULL;

    ALTER TABLE log_location ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE log_location SET channel_id = 2;
    ALTER TABLE log_location ALTER COLUMN channel_id SET NOT NULL;

    ALTER TABLE old_log_location ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE old_log_location SET channel_id = 2;
    ALTER TABLE old_log_location ALTER COLUMN channel_id SET NOT NULL;


    -- RESERVATION CHANNELISATION
    ALTER TABLE reservation ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE reservation SET channel_id = 2;
    ALTER TABLE reservation ALTER COLUMN channel_id SET NOT NULL;


    -- LOCATION CHANNELISATION
    ALTER TABLE location ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE location SET channel_id = 2 WHERE type_id = 1;
    --ALTER TABLE location ALTER COLUMN channel_id SET NOT NULL;

    -- QUANTITY CHANNELISATION
    ALTER TABLE quantity ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE quantity SET channel_id = 2;
    ALTER TABLE quantity ALTER COLUMN channel_id SET NOT NULL;

    -- STOCK SUMMARY CHANNELISATION
    ALTER TABLE product.stock_summary ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE product.stock_summary SET channel_id = 2;
    ALTER TABLE product.stock_summary ALTER COLUMN channel_id SET NOT NULL;

    -- HOTLIST CHANNELISATION
    ALTER TABLE hotlist_value ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    ALTER TABLE hotlist_value ADD COLUMN order_nr varchar(20) NULL;
    UPDATE hotlist_value SET channel_id = 2;
    ALTER TABLE hotlist_value ALTER COLUMN channel_id SET NOT NULL;

    -- STOCK TRANSFER CHANNELISATION
    ALTER TABLE stock_transfer ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE stock_transfer SET channel_id = 2;
    ALTER TABLE stock_transfer ALTER COLUMN channel_id SET NOT NULL;

    
    -- SAMPLE REQUEST CHANNELISATION
    ALTER TABLE sample_request ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE sample_request SET channel_id = 2;
    ALTER TABLE sample_request ALTER COLUMN channel_id SET NOT NULL;

    -- SAMPLE REQUEST CART CHANNELISATION
    ALTER TABLE sample_request_cart ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE sample_request_cart SET channel_id = 2;
    ALTER TABLE sample_request_cart ALTER COLUMN channel_id SET NOT NULL;

    -- remove obsolete column from product comments
    ALTER table product_comment DROP COLUMN instance_id;

    -- PRODUCT ATTRIBUTE CHANNELISATION
    ALTER TABLE product.attribute ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
    UPDATE product.attribute SET channel_id = 2;
    ALTER TABLE product.attribute ALTER COLUMN channel_id SET NOT NULL;

    -- INNER BOX
	ALTER TABLE inner_box ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
	UPDATE inner_box SET channel_id = 2;
	ALTER TABLE inner_box ALTER COLUMN channel_id SET NOT NULL;

    -- OUTER BOX
	ALTER TABLE box ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
	UPDATE box SET channel_id = 2;
	ALTER TABLE box ALTER COLUMN channel_id SET NOT NULL;


    -- REBUILD STOCK SUMMARY TRIGGERS & FUNCTIONS

    -- ordered quantity function and trigger

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

        SELECT INTO v_product_id, v_ordered_quantity, v_channel_id v.product_id, sum( soi.quantity ), po.channel_id
        FROM variant v, stock_order_item soi, stock_order so, purchase_order po
        WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
           AND v.id = soi.variant_id
           AND v.type_id = 1
           AND soi.cancel = false
           AND soi.stock_order_id = so.id
           AND so.purchase_order_id = po.id
        GROUP BY v.product_id, po.channel_id;


        UPDATE product.stock_summary SET ordered = v_ordered_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    CREATE TRIGGER ord_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON stock_order_item FOR EACH ROW EXECUTE PROCEDURE ordered_quantity_trigger();



    -- delivered quantity function and trigger

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

        SELECT INTO v_product_id, v_delivered_quantity, v_channel_id v.product_id, sum( di.quantity ), po.channel_id
               FROM variant v, purchase_order po, stock_order so, stock_order_item soi, link_delivery_item__stock_order_item lk, delivery_item di
               WHERE v.product_id = (SELECT product_id FROM stock_order WHERE id IN (SELECT stock_order_id from link_delivery__stock_order WHERE delivery_id = (SELECT delivery_id FROM delivery_item WHERE id = v_delivery_item_id)))
           AND v.id = soi.variant_id
           AND v.type_id = 1
           AND soi.id = lk.stock_order_item_id
           AND lk.delivery_item_id = di.id
           AND di.cancel = false
           AND soi.stock_order_id = so.id
           AND so.purchase_order_id = po.id
               GROUP BY v.product_id, po.channel_id;

        UPDATE product.stock_summary SET delivered = v_delivered_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    CREATE TRIGGER del_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON delivery_item FOR EACH ROW EXECUTE PROCEDURE delivered_quantity_trigger();


    -- main stock quantity function and trigger

    CREATE OR REPLACE FUNCTION mainstock_quantity_trigger() RETURNS
        trigger AS '
    DECLARE
        -- Variables
        v_variant_id	 INTEGER := NULL;
        v_quantity		 INTEGER := NULL;
        v_product_id	 INTEGER := NULL;
        v_channel_id	INTEGER := NULL;
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
           AND q.location_id IN ( select id from location where type_id = 1 )
               GROUP by v.product_id, q.channel_id;

        UPDATE product.stock_summary SET main_stock = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    CREATE TRIGGER main_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON quantity FOR EACH ROW EXECUTE PROCEDURE mainstock_quantity_trigger();


    -- sample stock quantity function and trigger

    CREATE OR REPLACE FUNCTION sample_quantity_trigger() RETURNS
        trigger AS '
    DECLARE
        -- Variables
        v_variant_id	 INTEGER := NULL;
        v_quantity		 INTEGER := NULL;
        v_product_id	 INTEGER := NULL;
        v_channel_id	INTEGER := NULL;
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

        UPDATE product.stock_summary SET sample_stock = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    CREATE TRIGGER sample_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON quantity FOR EACH ROW EXECUTE PROCEDURE sample_quantity_trigger();


    -- sample request quantity function and trigger

    CREATE OR REPLACE FUNCTION sample_request_trigger() RETURNS
        trigger AS '
    DECLARE
        -- Variables
        v_variant_id	 INTEGER := NULL;
        v_quantity		 INTEGER := NULL;
        v_product_id	 INTEGER := NULL;
        v_channel_id	INTEGER := NULL;
    BEGIN

        IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
            v_variant_id        := NEW.variant_id;
        ELSE
            v_variant_id        := OLD.variant_id;
        END IF;

        SELECT INTO v_product_id, v_quantity, v_channel_id v.product_id, count(st.*), st.channel_id
               FROM variant v, stock_transfer st
               WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
           AND v.id = st.variant_id
           AND st.status_id = 1
           AND st.type_id != 2
               GROUP by v.product_id, st.channel_id;

        UPDATE product.stock_summary SET sample_request = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    CREATE TRIGGER sample_req_tgr AFTER INSERT OR UPDATE OR DELETE ON stock_transfer FOR EACH ROW EXECUTE PROCEDURE sample_request_trigger();


    -- reserved stock quantity function and trigger

    CREATE OR REPLACE FUNCTION reserved_quantity_trigger() RETURNS
        trigger AS '
    DECLARE
        -- Variables
        v_variant_id	 INTEGER := NULL;
        v_quantity		 INTEGER := NULL;
        v_product_id	 INTEGER := NULL;
        v_channel_id	 INTEGER := NULL;
        channels         RECORD;
    BEGIN

        IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
            v_variant_id        := NEW.variant_id;
        ELSE
            v_variant_id        := OLD.variant_id;
        END IF;

        FOR channels IN SELECT id FROM channel LOOP

            v_channel_id = channels.id;

            SELECT INTO v_product_id, v_quantity v.product_id, count( r.* )
                   FROM variant v LEFT JOIN reservation r ON v.id = r.variant_id AND r.status_id = 2 AND r.channel_id = v_channel_id
                   WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
                   GROUP BY v.product_id;

            IF v_quantity IS NULL THEN
                    v_quantity = 0;
            END IF;

            UPDATE product.stock_summary SET reserved = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;  
            
        END LOOP;

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    CREATE TRIGGER reserved_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON reservation FOR EACH ROW EXECUTE PROCEDURE reserved_quantity_trigger();




    -- pre-pick stock quantity function and trigger

    CREATE OR REPLACE FUNCTION prepick_quantity_trigger() RETURNS
        trigger AS '
    DECLARE
        -- Variables
        v_variant_id	 INTEGER := NULL;
        v_quantity		 INTEGER := NULL;
        v_product_id	 INTEGER := NULL;
        v_channel_id	INTEGER := NULL;
    BEGIN

        IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
            v_variant_id        := NEW.variant_id;
        ELSE
            v_variant_id        := OLD.variant_id;
        END IF;

        SELECT INTO v_product_id, v_quantity, v_channel_id product_id, sum(total), channel_id FROM
               (
               SELECT v.product_id, count( si.* ) as total, o.channel_id
                   FROM variant v
                        LEFT JOIN shipment_item si ON v.id = si.variant_id AND si.shipment_item_status_id < 3
                        LEFT JOIN link_orders__shipment los ON si.shipment_id = los.shipment_id
                        LEFT JOIN orders o ON los.orders_id = o.id
               WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
                   GROUP BY v.product_id, o.channel_id
               UNION ALL
               SELECT v.product_id, count( si.* ) as total, st.channel_id
                   FROM variant v
                        LEFT JOIN shipment_item si ON v.id = si.variant_id AND si.shipment_item_status_id < 3
                        LEFT JOIN link_stock_transfer__shipment los ON si.shipment_id = los.shipment_id
                        LEFT JOIN stock_transfer st ON los.stock_transfer_id = st.id
               WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
                   GROUP BY v.product_id, st.channel_id
               ) AS bob
                GROUP BY product_id, channel_id
        ;

        IF v_quantity IS NULL THEN
            v_quantity := 0;
        END IF;

        IF v_channel_id IS NULL THEN
            UPDATE product.stock_summary SET pre_pick = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;
        ELSE 
            UPDATE product.stock_summary SET pre_pick = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;
        END IF; 

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    CREATE TRIGGER prepick_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON shipment_item FOR EACH ROW EXECUTE PROCEDURE prepick_quantity_trigger();



    -- cancel pending stock quantity function and trigger

    CREATE OR REPLACE FUNCTION canc_pending_quantity_trigger() RETURNS
        trigger AS '
    DECLARE
        -- Variables
        v_shipment_item_id	 INTEGER := NULL;
        v_old_status_id	 INTEGER := NULL;
        v_new_status_id	 INTEGER := NULL;
        v_quantity		 INTEGER := NULL;
        v_product_id	 INTEGER := NULL;
        v_channel_id	INTEGER := NULL;
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

            SELECT INTO v_product_id, v_quantity, v_channel_id v.product_id, count( si.* ), o.channel_id
               FROM variant v, cancelled_item ci, shipment_item si, link_orders__shipment los, orders o
               WHERE v.product_id = (SELECT product_id FROM variant WHERE id = (SELECT variant_id FROM shipment_item WHERE id = v_shipment_item_id))
               AND v.id = si.variant_id
               AND si.shipment_item_status_id = 10
               AND si.id = ci.shipment_item_id
               AND ci.adjusted = 0
               AND si.shipment_id = los.shipment_id
               AND los.orders_id = o.id
               GROUP by v.product_id, o.channel_id;

            UPDATE product.stock_summary SET cancel_pending = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;

        END IF;

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    CREATE TRIGGER canc_qty_tgr AFTER INSERT OR UPDATE OR DELETE ON shipment_item FOR EACH ROW EXECUTE PROCEDURE canc_pending_quantity_trigger();






    -- arrival date function and trigger

    CREATE OR REPLACE FUNCTION arrival_date_trigger() RETURNS
        trigger AS '
    DECLARE
        -- Variables
        v_date		    DATE    := NULL;
        v_product_id	INTEGER := NULL;
        v_channel_id	INTEGER := NULL;
    BEGIN

        IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
            v_date          := NEW.arrival_date;
            v_product_id    := NEW.product_id;
            v_channel_id    := NEW.channel_id;
        ELSE
            v_date          := OLD.arrival_date;
            v_product_id    := OLD.product_id;
            v_channel_id    := OLD.channel_id;
        END IF;

        IF v_date IS NOT NULL THEN
            UPDATE product.stock_summary SET arrival_date = v_date, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;
        END IF;        

        RETURN NEW;
    END;

    ' LANGUAGE plpgsql;

    CREATE TRIGGER arrival_date_tgr AFTER INSERT OR UPDATE OR DELETE ON product_channel FOR EACH ROW EXECUTE PROCEDURE arrival_date_trigger();



COMMIT;



BEGIN;

-- add some constraints a foreign keys to stock summary to prevent dodgy data
alter table product.stock_summary add constraint prod_channel unique (product_id, channel_id);
alter table product.stock_summary add constraint product_id_for_key foreign key (product_id) references product(id);
alter table product.stock_summary add constraint channel_id_for_key foreign key (channel_id) references channel(id);


COMMIT;
