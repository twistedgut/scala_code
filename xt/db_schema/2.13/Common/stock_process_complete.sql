-- Change complete type from integer to boolean
BEGIN;
    -- Drop views that depends on column
    DROP VIEW vw_list_rma;
    DROP VIEW vw_stock_process;

    -- Alter the column type
    ALTER TABLE stock_process ALTER complete DROP DEFAULT;
    ALTER TABLE stock_process
        ALTER complete TYPE boolean USING
            CASE
                WHEN complete=0 THEN FALSE
                ELSE TRUE
            END
    ;
    ALTER TABLE stock_process ALTER complete SET DEFAULT false;

    -- Regenerate the views
    CREATE VIEW vw_stock_process AS
    SELECT sp.id AS stock_process_id, sp.delivery_item_id, sp.quantity, sp.group_id, sp.type_id AS stock_process_type_id, spt.type AS stock_process_type, sp.status_id AS stock_process_status_id, sps.status AS stock_process_status, sp.complete, rsp.originating_uri_path, rsp.originating_sub_section_id, auths.section AS authorisation_section, authss.sub_section AS authorisation_sub_section, rsp.notes
    FROM stock_process sp
    JOIN stock_process_type spt ON sp.type_id = spt.id
    JOIN stock_process_status sps ON sp.status_id = sps.id
    LEFT JOIN (rtv_stock_process rsp
    JOIN authorisation_sub_section authss ON rsp.originating_sub_section_id = authss.id
    JOIN authorisation_section auths ON authss.authorisation_section_id = auths.id) ON rsp.stock_process_id = sp.id;

    CREATE VIEW vw_list_rma AS
    SELECT vw_sp.stock_process_id, vw_sp.stock_process_type, vw_sp.stock_process_status_id, vw_sp.stock_process_status, vw_dd.delivery_item_id, vw_dd.delivery_item_type, vw_dd.delivery_item_status, vw_pv.variant_id, vw_pv.sku, vw_pv.designer_id, vw_pv.designer, vw_pv.style_number, vw_pv.colour, vw_pv.designer_colour_code, vw_pv.designer_colour, vw_pv.product_type, vw_dd.date AS delivery_date, to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date, vw_sp.quantity
    FROM vw_stock_process vw_sp
    JOIN vw_delivery_details vw_dd ON vw_sp.delivery_item_id = vw_dd.delivery_item_id
    LEFT JOIN link_delivery_item__stock_order_item lnk_di_soi ON vw_dd.delivery_item_id = lnk_di_soi.delivery_item_id
    JOIN vw_stock_order_details vw_so ON lnk_di_soi.stock_order_item_id = vw_so.stock_order_item_id
    JOIN vw_product_variant vw_pv ON vw_so.variant_id = vw_pv.variant_id
    WHERE vw_sp.complete = false AND vw_sp.stock_process_type_id = 4
        UNION 
    SELECT vw_sp.stock_process_id, vw_sp.stock_process_type, vw_sp.stock_process_status_id, vw_sp.stock_process_status, vw_dd.delivery_item_id, vw_dd.delivery_item_type, vw_dd.delivery_item_status, vw_pv.variant_id, vw_pv.sku, vw_pv.designer_id, vw_pv.designer, vw_pv.style_number, vw_pv.colour, vw_pv.designer_colour_code, vw_pv.designer_colour, vw_pv.product_type, vw_dd.date AS delivery_date, to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date, vw_sp.quantity
    FROM vw_stock_process vw_sp
    JOIN vw_delivery_details vw_dd ON vw_sp.delivery_item_id = vw_dd.delivery_item_id
    LEFT JOIN link_delivery_item__return_item lnk_di_ri ON vw_dd.delivery_item_id = lnk_di_ri.delivery_item_id
    JOIN vw_return_details vw_r ON lnk_di_ri.return_item_id = vw_r.return_item_id
    JOIN vw_product_variant vw_pv ON vw_r.variant_id = vw_pv.variant_id
    WHERE vw_sp.complete = false AND vw_sp.stock_process_type_id = 4;
COMMIT;
