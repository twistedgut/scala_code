-- a lovely simple view for the purposes of product summary and related info
-- will be used in the worklist summary

BEGIN;


CREATE OR REPLACE VIEW product_summary AS SELECT
    p.id as product_id,
    v.id as variant_id,
    v.type_id as v_type_id,
    q.quantity as q_quantity,
    sz.id as size_id, 
    sz.size as size,
    soi.id as soi_id,
    soi.cancel as soi_cancel,
    soi.quantity as soi_quantity,
    di.id as di_id,
    di.quantity as di_quantity,
    st.status_id as st_status_id,
    st.type_id as st_type_id,
    l.id as location_id,
    l.location as location,
    stt.id as stt_type_id,
    stt.type as stt_type,
    d.date as d_date,
    so.start_ship_date as so_start_ship_date,
    pp.uk_landed_cost as pp_cost_gbp,
    r.id as r_id,
    r.status_id as r_status_id

FROM
    stock_order so
    RIGHT JOIN stock_order_item soi
        ON soi.stock_order_id = so.id
    LEFT JOIN variant v
        ON v.id = soi.variant_id
    JOIN size sz
        ON sz.id = v.size_id
    LEFT JOIN reservation r
        ON r.variant_id = v.id
    LEFT JOIN quantity q
        ON q.variant_id = v.id
    LEFT JOIN location l
        ON l.id = q.location_id
    LEFT JOIN product p
        ON p.id = v.product_id
    LEFT JOIN price_purchase pp
        ON pp.product_id = p.id
    LEFT JOIN stock_transfer st
        ON st.variant_id = v.id
    LEFT JOIN stock_transfer_type stt
        ON stt.id = st.type_id
    LEFT JOIN link_delivery_item__stock_order_item link
        ON link.stock_order_item_id = soi.id
    JOIN delivery_item di
        ON di.id = link.delivery_item_id
    LEFT JOIN delivery d
        ON d.id = di.delivery_id
;

GRANT ALL ON public.product_summary TO www;

COMMIT;
