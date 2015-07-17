/**************************************
* SRD-71: product sort management
*
* Usability Phase II: New tables and 
* views for product sort management 
* 
**************************************/

BEGIN;

/****************
* Create Tables
****************/

CREATE TABLE product.pws_sort (
	product_id integer PRIMARY KEY REFERENCES product(id),
    price numeric NOT NULL,    
	price_weighted numeric NOT NULL,
    available_to_sell numeric NOT NULL,
	available_to_sell_weighted numeric NOT NULL,
	pcnt_sizes_in_stock numeric NOT NULL,
	pcnt_sizes_in_stock_weighted numeric NOT NULL,
    inverse_upload_days numeric NOT NULL,
    inverse_upload_days_weighted numeric NOT NULL,
    score numeric NOT NULL,
    score_offset numeric NOT NULL,
    sort_order integer NOT NULL,
    created timestamp without time zone NOT NULL DEFAULT now()
);
CREATE INDEX ix_pws_sort__score ON product.pws_sort(score);
CREATE UNIQUE INDEX uix_pws_sort__sort_order ON product.pws_sort(sort_order);
GRANT ALL ON product.pws_sort TO www;



CREATE TABLE product.pws_sort_adjust (
    id serial PRIMARY KEY,
    action varchar(20) NOT NULL,
    sort_score_offset numeric NOT NULL DEFAULT 0
);
GRANT ALL ON product.pws_sort_adjust TO www;
GRANT ALL ON product.pws_sort_adjust_id_seq TO www;

INSERT INTO product.pws_sort_adjust (id, action, sort_score_offset) VALUES (0, 'Default', 0);
INSERT INTO product.pws_sort_adjust (id, action, sort_score_offset) VALUES (1, 'Top', 1000);
INSERT INTO product.pws_sort_adjust (id, action, sort_score_offset) VALUES (2, 'Bottom', -1000);
SELECT setval('product.pws_sort_adjust_id_seq', (SELECT max(id) FROM product.pws_sort_adjust));


ALTER TABLE product_attribute ADD COLUMN pws_sort_adjust_id integer NOT NULL DEFAULT 0 REFERENCES product.pws_sort_adjust(id);


/**************
* Create Views
**************/

-- Uploaded products
CREATE OR REPLACE VIEW product.vw_uploaded_products AS
    SELECT
        pli.product_id
    ,   ll.due AS upload_date
    ,   p.visible
    FROM list.list ll
    INNER JOIN list.type lt
        ON (ll.type_id = lt.id)
    INNER JOIN list.item li
        ON (li.list_id = ll.id)
    INNER JOIN product.list_item pli
        ON (pli.listitem_id = li.id)
    INNER JOIN public.product p
        ON (pli.product_id = p.id)
    WHERE lt.name = 'Upload'
    AND ll.due < current_timestamp
    AND p.live IS True
;
GRANT SELECT ON product.vw_uploaded_products TO www;


-- Available to sell
CREATE OR REPLACE VIEW product.vw_available_to_sell AS
    SELECT
        p.id AS product_id
    ,   saleable.variant_id
    ,   p.id || '-' || lpad(CAST(saleable.size_id AS varchar), 3, '0') AS sku
    ,   CASE
            WHEN SUM(saleable.quantity) <= 0 THEN 0
            ELSE SUM(saleable.quantity)
        END AS quantity
    FROM public.product p
    INNER JOIN
        (
            SELECT product_id, size_id, id AS variant_id, 0 AS quantity
            FROM variant
            WHERE type_id = (SELECT id FROM variant_type WHERE type = 'Stock')
        UNION ALL        
            SELECT v.product_id, v.size_id, q.variant_id, SUM(q.quantity) AS quantity
            FROM quantity q
            INNER JOIN variant v
                ON (q.variant_id = v.id)
            INNER JOIN location l
                ON (q.location_id = l.id)
            AND l.type_id = (SELECT id FROM location_type WHERE type = 'DC1')
            GROUP BY v.product_id, v.size_id, q.variant_id
        UNION ALL
            SELECT v.product_id, v.size_id, r.variant_id, -COUNT(*) AS quantity
            FROM reservation r
            INNER JOIN variant v
                ON (r.variant_id = v.id)
            AND r.status_id = (SELECT id FROM reservation_status WHERE status = 'Uploaded')
            GROUP BY v.product_id, v.size_id, r.variant_id
        UNION ALL
            SELECT v.product_id, v.size_id, si.variant_id, -COUNT(*) AS quantity
            FROM shipment_item si
            INNER JOIN variant v
                ON (si.variant_id = v.id)
            AND si.shipment_item_status_id IN (SELECT id FROM shipment_item_status WHERE status IN ('New', 'Selected', 'Picked'))
            GROUP BY v.product_id, v.size_id, si.variant_id 
        UNION ALL
            SELECT v.product_id, v.size_id, si.variant_id, -COUNT(*) AS quantity
            FROM cancelled_item ci
            INNER JOIN shipment_item si
                ON (ci.shipment_item_id = si.id)
            INNER JOIN variant v
                ON (si.variant_id = v.id)
            WHERE ci.adjusted = 0
            AND si.shipment_item_status_id = (SELECT id FROM shipment_item_status WHERE status IN ('Cancelled'))
            GROUP BY v.product_id, v.size_id, si.variant_id
        ) AS saleable
        ON (saleable.product_id = p.id)
    GROUP BY p.id, saleable.variant_id, p.id || '-' || lpad(CAST(saleable.size_id AS varchar), 3, '0')
;
GRANT SELECT ON product.vw_available_to_sell TO www;

COMMIT;

