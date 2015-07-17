-- WHM-444 : Include RTVI id in Faulty GI list

BEGIN WORK;

    CREATE OR REPLACE VIEW vw_rtv_inspection_pick_requested AS
        SELECT
            vw_riprd.product_id,
            vw_riprd.origin,
            vw_riprd.delivery_id,
            SUM(vw_riprd.quantity) AS quantity_requested,
            vw_riprd.rtv_inspection_pick_request_id
        FROM vw_rtv_inspection_pick_request_details vw_riprd
        WHERE vw_riprd.status IN ('New', 'Picking')
        GROUP BY
            vw_riprd.product_id,
            vw_riprd.origin,
            vw_riprd.delivery_id,
            vw_riprd.rtv_inspection_pick_request_id;

    CREATE OR REPLACE VIEW vw_rtv_inspection_list AS
        SELECT
            vw_ris.product_id,
            vw_ris.channel_id,
            vw_ris.sales_channel,
            vw_ris.origin,
            vw_ris.rtv_quantity_date,
            vw_ris.txt_rtv_quantity_date,
            vw_ris.designer_id,
            vw_ris.designer,
            vw_ris.colour,
            vw_ris.product_type,
            vw_ris.delivery_id,
            vw_ris.delivery_date,
            vw_ris.txt_delivery_date,
            vw_ris.sum_quantity,
            COALESCE(vw_ripr.quantity_requested, 0) AS quantity_requested,
            vw_ris.sum_quantity - COALESCE(vw_ripr.quantity_requested, 0) AS quantity_remaining,
            vw_ripr.rtv_inspection_pick_request_id
        FROM vw_rtv_inspection_stock vw_ris
        LEFT JOIN vw_rtv_inspection_pick_requested vw_ripr
            ON vw_ris.product_id = vw_ripr.product_id
            AND vw_ris.origin::text = vw_ripr.origin::text
            AND vw_ris.delivery_id = vw_ripr.delivery_id;

COMMIT;
