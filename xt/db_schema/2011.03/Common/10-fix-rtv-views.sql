BEGIN;

-- Believe it or not, all this mess is only dropping 1 column from 1 view, and replacing 1 column in 1 other view
-- the rest is fallout

-- we are dropping all referernces to location.type_id
-- replacing them with quantity.status_id

DROP VIEW vw_rtv_shipment_validate_pick;
DROP VIEW vw_rtv_shipment_picklist;
DROP VIEW vw_rtv_inspection_validate_pick;
DROP VIEW vw_rtv_inspection_list;
DROP VIEW vw_rtv_inspection_pick_requested;
DROP VIEW vw_rtv_inspection_pick_request_details;
DROP VIEW vw_rtv_shipment_details_with_results;
DROP VIEW vw_rtv_shipment_details;
DROP VIEW vw_rma_request_details;
DROP VIEW vw_rtv_workstation_stock;
DROP VIEW vw_rtv_inspection_stock;
DROP VIEW vw_rtv_stock_details;
DROP VIEW vw_location_details;

CREATE VIEW vw_location_details AS
    SELECT
      l.id AS location_id,
      l.location,
      substring((l.location)::text, E'\\A(\\d{2})\\d[a-zA-Z]-?\\d{3,4}[a-zA-Z]\\Z'::text) AS loc_dc,
      substring((l.location)::text, E'\\A\\d{2}(\\d)[a-zA-Z]-?\\d{3,4}[a-zA-Z]\\Z'::text) AS loc_floor,
      substring((l.location)::text, E'\\A\\d{2}\\d([a-zA-Z])-?\\d{3,4}[a-zA-Z]\\Z'::text) AS loc_zone,
      substring((l.location)::text, E'\\A\\d{2}\\d[a-zA-Z]-?(\\d{3,4})[a-zA-Z]\\Z'::text) AS loc_section,
      substring((l.location)::text, E'\\A\\d{2}\\d[a-zA-Z]-?\\d{3,4}([a-zA-Z])\\Z'::text) AS loc_shelf
     FROM
       location l
;

CREATE VIEW vw_rtv_stock_details AS
    SELECT
      rq.id AS rtv_quantity_id,
      rq.channel_id,
      rq.variant_id,
      rq.location_id,
      rq.origin,
      rq.date_created AS rtv_quantity_date,
      to_char(rq.date_created, 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date,
      vw_ld.location,
      vw_ld.loc_dc,
      vw_ld.loc_floor,
      vw_ld.loc_zone,
      vw_ld.loc_section,
      vw_ld.loc_shelf,
      rq.quantity,
      rq.fault_type_id,
      ft.fault_type,
      rq.fault_description,
      vw_dd.delivery_id,
      vw_dd.delivery_item_id,
      vw_dd.delivery_item_type,
      vw_dd.delivery_item_status,
      vw_dd.date AS delivery_date,
      to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date,
      vw_pv.product_id,
      vw_pv.size_id,
      vw_pv.size,
      vw_pv.designer_size_id,
      vw_pv.designer_size,
      vw_pv.sku,
      vw_pv.name,
      vw_pv.description,
      vw_pv.designer_id,
      vw_pv.designer,
      vw_pv.style_number,
      vw_pv.colour,
      vw_pv.designer_colour_code,
      vw_pv.designer_colour,
      vw_pv.product_type_id,
      vw_pv.product_type,
      vw_pv.classification_id,
      vw_pv.classification,
      vw_pv.season_id,
      vw_pv.season,
      rrd.rma_request_id,
      rq.status_id AS quantity_status_id
    FROM 
      rtv_quantity rq
      JOIN vw_location_details vw_ld ON rq.location_id = vw_ld.location_id
      JOIN vw_product_variant vw_pv ON rq.variant_id = vw_pv.variant_id AND rq.channel_id = vw_pv.channel_id
      LEFT JOIN item_fault_type ft ON rq.fault_type_id = ft.id
      LEFT JOIN rma_request_detail rrd ON rq.id = rrd.rtv_quantity_id
      LEFT JOIN vw_delivery_details vw_dd ON rq.delivery_item_id = vw_dd.delivery_item_id
;

CREATE VIEW vw_rtv_inspection_stock AS
    SELECT
      vw_rtv_stock_details.product_id,
      vw_rtv_stock_details.channel_id,
      ch.name AS sales_channel,
      vw_rtv_stock_details.origin,
      max(vw_rtv_stock_details.rtv_quantity_date) AS rtv_quantity_date,
      to_char(max(vw_rtv_stock_details.rtv_quantity_date), 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date,
      vw_rtv_stock_details.designer_id,
      vw_rtv_stock_details.designer,
      vw_rtv_stock_details.colour,
      vw_rtv_stock_details.product_type,
      vw_rtv_stock_details.delivery_id,
      vw_rtv_stock_details.delivery_date,
      vw_rtv_stock_details.txt_delivery_date,
      sum(vw_rtv_stock_details.quantity) AS sum_quantity
    FROM
      vw_rtv_stock_details
      JOIN flow.status ON status.name = 'RTV Goods In'::text AND vw_rtv_stock_details.quantity_status_id = status.id
      JOIN channel ch ON vw_rtv_stock_details.channel_id = ch.id
    GROUP BY
      vw_rtv_stock_details.product_id,
      vw_rtv_stock_details.channel_id,
      ch.name,
      vw_rtv_stock_details.origin,
      vw_rtv_stock_details.designer_id,
      vw_rtv_stock_details.designer,
      vw_rtv_stock_details.colour,
      vw_rtv_stock_details.product_type,
      vw_rtv_stock_details.delivery_id,
      vw_rtv_stock_details.delivery_date,
      vw_rtv_stock_details.txt_delivery_date
;

CREATE VIEW vw_rtv_workstation_stock AS
    SELECT
      vw_rtv_stock_details.channel_id,
      channel.name AS sales_channel,
      vw_rtv_stock_details.location_id,
      vw_rtv_stock_details.location,
      vw_rtv_stock_details.product_id,
      vw_rtv_stock_details.origin,
      max(vw_rtv_stock_details.rtv_quantity_date) AS rtv_quantity_date,
      to_char(max(vw_rtv_stock_details.rtv_quantity_date), 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date,
      vw_rtv_stock_details.designer_id,
      vw_rtv_stock_details.designer,
      vw_rtv_stock_details.colour,
      vw_rtv_stock_details.product_type,
      vw_rtv_stock_details.delivery_id,
      vw_rtv_stock_details.delivery_date,
      vw_rtv_stock_details.txt_delivery_date,
      sum(vw_rtv_stock_details.quantity) AS sum_quantity
    FROM
      vw_rtv_stock_details
      JOIN flow.status ON status.name = 'RTV Workstation'::text AND vw_rtv_stock_details.quantity_status_id = status.id
      JOIN channel ON vw_rtv_stock_details.channel_id = channel.id
    GROUP BY
      vw_rtv_stock_details.channel_id,
      channel.name,
      vw_rtv_stock_details.location_id,
      vw_rtv_stock_details.location,
      vw_rtv_stock_details.product_id,
      vw_rtv_stock_details.origin,
      vw_rtv_stock_details.designer_id,
      vw_rtv_stock_details.designer,
      vw_rtv_stock_details.colour,
      vw_rtv_stock_details.product_type,
      vw_rtv_stock_details.delivery_id,
      vw_rtv_stock_details.delivery_date,
      vw_rtv_stock_details.txt_delivery_date
;

CREATE VIEW vw_rma_request_details AS
    SELECT rr.id AS rma_request_id,
      rr.channel_id,
      ch.name AS sales_channel,
      rr.operator_id,
      op.name AS operator_name,
      op.email_address,
      rr.status_id AS rma_request_status_id,
      rrs.status AS rma_request_status,
      rr.date_request,
      to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_request,
      rr.date_followup,
      to_char(rr.date_followup, 'DD-Mon-YYYY'::text) AS txt_date_followup,
      rr.rma_number,
      rr.comments AS rma_request_comments,
      rrd.id AS rma_request_detail_id,
      rrd.rtv_quantity_id,
      vw_pv.product_id,
      vw_pv.size_id,
      vw_pv.sku,
      vw_pv.wholesale_currency,
      vw_pv.original_wholesale,
      vw_pv.variant_id,
      vw_pv.designer_id,
      vw_pv.designer,
      vw_pv.season_id,
      vw_pv.season,
      vw_pv.style_number,
      vw_pv.colour,
      vw_pv.designer_colour_code,
      vw_pv.designer_colour,
      vw_pv.name,
      vw_pv.description,
      vw_pv.size,
      vw_pv.designer_size,
      vw_pv.nap_size,
      vw_pv.product_type,
      vw_dd.delivery_item_id,
      vw_dd.delivery_item_type,
      vw_dd.date AS delivery_date,
      to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date,
      rrd.quantity AS rma_request_detail_quantity,
      ift.fault_type,
      rrd.fault_description,
      rrdt.id AS rma_request_detail_type_id,
      rrdt.type AS rma_request_detail_type,
      rrds.id AS rma_request_detail_status_id,
      rrds.status AS rma_request_detail_status,
      vw_rstkd.quantity AS rtv_stock_detail_quantity,
      vw_rstkd.location,
      vw_rstkd.loc_dc,
      vw_rstkd.loc_floor,
      vw_rstkd.loc_zone,
      vw_rstkd.loc_section,
      vw_rstkd.loc_shelf,
      vw_rstkd.quantity_status_id
    FROM
      rma_request rr
      JOIN channel ch ON rr.channel_id = ch.id
      JOIN rma_request_status rrs ON rr.status_id = rrs.id
      JOIN operator op ON rr.operator_id = op.id
      JOIN rma_request_detail rrd ON rrd.rma_request_id = rr.id
      JOIN rma_request_detail_type rrdt ON rrd.type_id = rrdt.id
      JOIN item_fault_type ift ON rrd.fault_type_id = ift.id
      JOIN rma_request_detail_status rrds ON rrd.status_id = rrds.id
      LEFT JOIN vw_rtv_stock_details vw_rstkd ON rrd.rtv_quantity_id = vw_rstkd.rtv_quantity_id
      JOIN vw_product_variant vw_pv ON rrd.variant_id = vw_pv.variant_id AND rr.channel_id = vw_pv.channel_id
      LEFT JOIN vw_delivery_details vw_dd ON rrd.delivery_item_id = vw_dd.delivery_item_id
;

CREATE VIEW vw_rtv_shipment_details AS
    SELECT rs.id AS rtv_shipment_id,
      rs.channel_id,
      ch.name AS sales_channel,
      rs.designer_rtv_carrier_id,
      vw_drc.rtv_carrier_name,
      vw_drc.account_ref AS carrier_account_ref,
      rs.designer_rtv_address_id,
      vw_dra.contact_name,
      vw_dra.address_line_1,
      vw_dra.address_line_2,
      vw_dra.address_line_3,
      vw_dra.town_city,
      vw_dra.region_county,
      vw_dra.postcode_zip,
      vw_dra.country,
      rs.date_time AS rtv_shipment_date,
      to_char(rs.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_shipment_date,
      rs.status_id AS rtv_shipment_status_id,
      rss.status AS rtv_shipment_status,
      rs.airway_bill,
      vw_rrd.rma_request_id,
      vw_rrd.operator_id,
      vw_rrd.operator_name,
      vw_rrd.email_address,
      vw_rrd.rma_request_status_id,
      vw_rrd.rma_request_status,
      vw_rrd.date_request,
      vw_rrd.txt_date_request,
      vw_rrd.date_followup,
      vw_rrd.txt_date_followup,
      vw_rrd.rma_number,
      vw_rrd.rma_request_comments,
      vw_rrd.rma_request_detail_id,
      vw_rrd.rtv_quantity_id,
      vw_rrd.product_id,
      vw_rrd.size_id,
      vw_rrd.sku,
      vw_rrd.wholesale_currency,
      vw_rrd.original_wholesale,
      vw_rrd.variant_id,
      vw_rrd.designer_id,
      vw_rrd.designer,
      vw_rrd.season_id,
      vw_rrd.season,
      vw_rrd.style_number,
      vw_rrd.colour,
      vw_rrd.designer_colour_code,
      vw_rrd.designer_colour,
      vw_rrd.name,
      vw_rrd.description,
      vw_rrd.size,
      vw_rrd.designer_size,
      vw_rrd.nap_size,
      vw_rrd.product_type,
      vw_rrd.delivery_item_id,
      vw_rrd.delivery_item_type,
      vw_rrd.delivery_date,
      vw_rrd.txt_delivery_date,
      vw_rrd.rma_request_detail_quantity,
      vw_rrd.fault_type,
      vw_rrd.fault_description,
      vw_rrd.rma_request_detail_type_id,
      vw_rrd.rma_request_detail_type,
      vw_rrd.rma_request_detail_status_id,
      vw_rrd.rma_request_detail_status,
      vw_rrd.rtv_stock_detail_quantity,
      vw_rrd.location,
      vw_rrd.loc_dc,
      vw_rrd.loc_floor,
      vw_rrd.loc_zone,
      vw_rrd.loc_section,
      vw_rrd.loc_shelf,
      vw_rrd.quantity_status_id,
      rsd.id AS rtv_shipment_detail_id,
      rsd.quantity AS rtv_shipment_detail_quantity,
      rsd.status_id AS rtv_shipment_detail_status_id,
      rsds.status AS rtv_shipment_detail_status
    FROM
      rtv_shipment rs
      JOIN channel ch ON rs.channel_id = ch.id
      JOIN rtv_shipment_status rss ON rs.status_id = rss.id
      JOIN rtv_shipment_detail rsd ON rsd.rtv_shipment_id = rs.id
      JOIN rtv_shipment_detail_status rsds ON rsd.status_id = rsds.id
      JOIN vw_designer_rtv_carrier vw_drc ON rs.designer_rtv_carrier_id = vw_drc.designer_rtv_carrier_id
      JOIN vw_designer_rtv_address vw_dra ON rs.designer_rtv_address_id = vw_dra.designer_rtv_address_id
      JOIN vw_rma_request_details vw_rrd ON rsd.rma_request_detail_id = vw_rrd.rma_request_detail_id
;

CREATE VIEW vw_rtv_shipment_details_with_results AS
    SELECT vw_rsd.rtv_shipment_id,
      vw_rsd.channel_id,
      ch.name AS sales_channel,
      vw_rsd.designer_rtv_carrier_id,
      vw_rsd.rtv_carrier_name,
      vw_rsd.carrier_account_ref,
      vw_rsd.designer_rtv_address_id,
      vw_rsd.contact_name,
      vw_rsd.address_line_1,
      vw_rsd.address_line_2,
      vw_rsd.address_line_3,
      vw_rsd.town_city,
      vw_rsd.region_county,
      vw_rsd.postcode_zip,
      vw_rsd.country,
      vw_rsd.rtv_shipment_date,
      vw_rsd.txt_rtv_shipment_date,
      vw_rsd.rtv_shipment_status_id,
      vw_rsd.rtv_shipment_status,
      vw_rsd.airway_bill,
      vw_rsd.rma_request_id,
      vw_rsd.operator_id,
      vw_rsd.operator_name,
      vw_rsd.email_address,
      vw_rsd.rma_request_status_id,
      vw_rsd.rma_request_status,
      vw_rsd.date_request,
      vw_rsd.txt_date_request,
      vw_rsd.date_followup,
      vw_rsd.txt_date_followup,
      vw_rsd.rma_number,
      vw_rsd.rma_request_comments,
      vw_rsd.rma_request_detail_id,
      vw_rsd.rtv_quantity_id,
      vw_rsd.product_id,
      vw_rsd.size_id,
      vw_rsd.sku,
      vw_rsd.variant_id,
      vw_rsd.designer_id,
      vw_rsd.designer,
      vw_rsd.season_id,
      vw_rsd.season,
      vw_rsd.style_number,
      vw_rsd.colour,
      vw_rsd.designer_colour_code,
      vw_rsd.designer_colour,
      vw_rsd.name,
      vw_rsd.description,
      vw_rsd.size,
      vw_rsd.designer_size,
      vw_rsd.nap_size,
      vw_rsd.product_type,
      vw_rsd.delivery_item_id,
      vw_rsd.delivery_item_type,
      vw_rsd.delivery_date,
      vw_rsd.txt_delivery_date,
      vw_rsd.rma_request_detail_quantity,
      vw_rsd.fault_type,
      vw_rsd.fault_description,
      vw_rsd.rma_request_detail_type_id,
      vw_rsd.rma_request_detail_type,
      vw_rsd.rma_request_detail_status_id,
      vw_rsd.rma_request_detail_status,
      vw_rsd.rtv_stock_detail_quantity,
      vw_rsd.location,
      vw_rsd.loc_dc,
      vw_rsd.loc_floor,
      vw_rsd.loc_zone,
      vw_rsd.loc_section,
      vw_rsd.loc_shelf,
      vw_rsd.quantity_status_id,
      vw_rsd.rtv_shipment_detail_id,
      vw_rsd.rtv_shipment_detail_quantity,
      vw_rsd.rtv_shipment_detail_status_id,
      vw_rsd.rtv_shipment_detail_status,
      COALESCE(vw_rsdrtr.unknown, (0)::numeric) AS result_total_unknown,
      COALESCE(vw_rsdrtr.credited, (0)::numeric) AS result_total_credited,
      COALESCE(vw_rsdrtr.repaired, (0)::numeric) AS result_total_repaired,
      COALESCE(vw_rsdrtr.replaced, (0)::numeric) AS result_total_replaced,
      COALESCE(vw_rsdrtr.dead, (0)::numeric) AS result_total_dead,
      COALESCE(vw_rsdrtr.stock_swapped, (0)::numeric) AS result_total_stock_swapped
    FROM
      vw_rtv_shipment_details vw_rsd
      JOIN channel ch ON vw_rsd.channel_id = ch.id
      LEFT JOIN vw_rtv_shipment_detail_result_totals_row vw_rsdrtr ON vw_rsdrtr.rtv_shipment_detail_id = vw_rsd.rtv_shipment_detail_id
;

CREATE VIEW vw_rtv_inspection_pick_request_details AS
    SELECT ripr.id AS rtv_inspection_pick_request_id,
      ripr.date_time,
      to_char(ripr.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_time,
      riprd.id AS rtv_inspection_pick_request_item_id,
      riprd.rtv_quantity_id,
      ripr.status_id,
      riprs.status,
      vw_rstkd.product_id,
      vw_rstkd.origin,
      vw_rstkd.sku,
      vw_rstkd.designer,
      vw_rstkd.name,
      vw_rstkd.colour,
      vw_rstkd.designer_size,
      vw_rstkd.variant_id,
      vw_rstkd.delivery_id,
      vw_rstkd.delivery_item_id,
      vw_rstkd.quantity,
      vw_rstkd.fault_type,
      vw_rstkd.fault_description,
      vw_rstkd.location,
      vw_rstkd.loc_dc,
      vw_rstkd.loc_floor,
      vw_rstkd.loc_zone,
      vw_rstkd.loc_section,
      vw_rstkd.loc_shelf,
      vw_rstkd.quantity_status_id
    FROM
      rtv_inspection_pick_request ripr
      JOIN rtv_inspection_pick_request_status riprs ON ripr.status_id = riprs.id
      JOIN rtv_inspection_pick_request_detail riprd ON riprd.rtv_inspection_pick_request_id = ripr.id
      JOIN vw_rtv_stock_details vw_rstkd ON riprd.rtv_quantity_id = vw_rstkd.rtv_quantity_id
;

CREATE VIEW vw_rtv_inspection_pick_requested AS
    SELECT vw_rtv_inspection_pick_request_details.product_id,
      vw_rtv_inspection_pick_request_details.origin,
      vw_rtv_inspection_pick_request_details.delivery_id,
      sum(vw_rtv_inspection_pick_request_details.quantity) AS quantity_requested
    FROM
      vw_rtv_inspection_pick_request_details
    WHERE
      (vw_rtv_inspection_pick_request_details.status)::text = ANY (
        (ARRAY['New'::character varying, 'Picking'::character varying])::text[]
      )
    GROUP BY
      vw_rtv_inspection_pick_request_details.product_id,
      vw_rtv_inspection_pick_request_details.origin,
      vw_rtv_inspection_pick_request_details.delivery_id
;

CREATE VIEW vw_rtv_inspection_list AS
    SELECT vw_ris.product_id,
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
      COALESCE(vw_ripr.quantity_requested, (0)::bigint) AS quantity_requested,
      (vw_ris.sum_quantity - COALESCE(vw_ripr.quantity_requested, (0)::bigint)) AS quantity_remaining
    FROM
      vw_rtv_inspection_stock vw_ris
      LEFT JOIN vw_rtv_inspection_pick_requested vw_ripr ON vw_ris.product_id = vw_ripr.product_id AND (vw_ris.origin)::text = (vw_ripr.origin)::text AND vw_ris.delivery_id = vw_ripr.delivery_id
;

CREATE VIEW vw_rtv_inspection_validate_pick AS
    SELECT a.rtv_inspection_pick_request_id,
      a.status_id,
      a.status,
      a.location,
      a.loc_dc,
      a.loc_floor,
      a.loc_zone,
      a.loc_section,
      a.loc_shelf,
      a.quantity_status_id,
      a.sku,
      a.sum_picklist_quantity,
      COALESCE(b.picked_quantity, (0)::bigint) AS picked_quantity,
      (a.sum_picklist_quantity - COALESCE(b.picked_quantity, (0)::bigint)) AS remaining_to_pick
    FROM
     (SELECT
        vw_rtv_inspection_pick_request_details.rtv_inspection_pick_request_id,
        vw_rtv_inspection_pick_request_details.status_id,
        vw_rtv_inspection_pick_request_details.status,
        vw_rtv_inspection_pick_request_details.location,
        vw_rtv_inspection_pick_request_details.loc_dc,
        vw_rtv_inspection_pick_request_details.loc_floor,
        vw_rtv_inspection_pick_request_details.loc_zone,
        vw_rtv_inspection_pick_request_details.loc_section,
        vw_rtv_inspection_pick_request_details.loc_shelf,
        vw_rtv_inspection_pick_request_details.quantity_status_id,
        vw_rtv_inspection_pick_request_details.sku,
        sum(vw_rtv_inspection_pick_request_details.quantity) AS sum_picklist_quantity
      FROM
        vw_rtv_inspection_pick_request_details
      WHERE
        (vw_rtv_inspection_pick_request_details.status)::text = ANY (
          (ARRAY['New'::character varying, 'Picking'::character varying])::text[]
        )
      GROUP BY
        vw_rtv_inspection_pick_request_details.rtv_inspection_pick_request_id,
        vw_rtv_inspection_pick_request_details.status_id,
        vw_rtv_inspection_pick_request_details.status,
        vw_rtv_inspection_pick_request_details.sku,
        vw_rtv_inspection_pick_request_details.location,
        vw_rtv_inspection_pick_request_details.loc_dc,
        vw_rtv_inspection_pick_request_details.loc_floor,
        vw_rtv_inspection_pick_request_details.loc_zone,
        vw_rtv_inspection_pick_request_details.loc_section,
        vw_rtv_inspection_pick_request_details.loc_shelf,
        vw_rtv_inspection_pick_request_details.quantity_status_id
     ) a
    LEFT JOIN
     (SELECT
        rtv_inspection_pick.rtv_inspection_pick_request_id,
        rtv_inspection_pick.location,
        rtv_inspection_pick.sku,
        count(*) AS picked_quantity
      FROM
        rtv_inspection_pick
      WHERE
        rtv_inspection_pick.cancelled IS NULL
      GROUP BY
        rtv_inspection_pick.rtv_inspection_pick_request_id,
        rtv_inspection_pick.sku,
        rtv_inspection_pick.location
     ) b
     ON a.sku = b.sku AND (a.location)::text = (b.location)::text AND a.rtv_inspection_pick_request_id = b.rtv_inspection_pick_request_id
;

CREATE VIEW vw_rtv_shipment_picklist AS
    SELECT rs.id AS rtv_shipment_id,
      rs.channel_id,
      ch.name AS sales_channel,
      rs.status_id AS rtv_shipment_status_id,
      rss.status AS rtv_shipment_status,
      rs.date_time AS rtv_shipment_date,
      to_char(rs.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_shipment_date,
      rsd.status_id AS rtv_shipment_detail_status_id,
      rsds.status AS rtv_shipment_detail_status,
      rsd.quantity AS rtv_shipment_detail_quantity,
      rr.id AS rma_request_id,
      rr.status_id AS rma_request_status_id,
      rr.date_request,
      to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_request,
      rrd.status_id AS rma_request_detail_status_id,
      rrd.fault_description,
      vw_pv.designer,
      vw_pv.sku,
      vw_pv.name,
      vw_pv.description,
      vw_pv.designer_size,
      vw_pv.colour,
      ift.fault_type,
      vw_ld.location,
      vw_ld.loc_dc,
      vw_ld.loc_floor,
      vw_ld.loc_zone,
      vw_ld.loc_section,
      vw_ld.loc_shelf,
      rq.status_id as quantity_status_id,
      rnl.original_location
    FROM
      rtv_shipment rs
      JOIN channel ch ON rs.channel_id = ch.id
      JOIN rtv_shipment_status rss ON rs.status_id = rss.id
      JOIN rtv_shipment_detail rsd ON rsd.rtv_shipment_id = rs.id
      JOIN rtv_shipment_detail_status rsds ON rsd.status_id = rsds.id
      JOIN rma_request_detail rrd ON rrd.id = rsd.rma_request_detail_id
      JOIN vw_product_variant vw_pv ON rrd.variant_id = vw_pv.variant_id AND rs.channel_id = vw_pv.channel_id
      JOIN item_fault_type ift ON rrd.fault_type_id = ift.id
      JOIN rtv_quantity rq ON rrd.rtv_quantity_id = rq.id
      JOIN vw_location_details vw_ld ON rq.location_id = vw_ld.location_id
      JOIN rma_request rr ON rrd.rma_request_id = rr.id
      LEFT JOIN rtv_nonfaulty_location rnl ON rrd.rtv_quantity_id = rnl.rtv_quantity_id;

CREATE VIEW vw_rtv_shipment_validate_pick AS
    SELECT a.rtv_shipment_id,
      a.channel_id,
      a.sales_channel,
      a.rtv_shipment_status_id,
      a.rtv_shipment_status,
      a.location,
      a.loc_dc,
      a.loc_floor,
      a.loc_zone,
      a.loc_section,
      a.loc_shelf,
      a.quantity_status_id,
      a.sku,
      a.sum_picklist_quantity,
      COALESCE(b.picked_quantity, (0)::bigint) AS picked_quantity,
      (a.sum_picklist_quantity - COALESCE(b.picked_quantity, (0)::bigint)) AS remaining_to_pick
    FROM 
     (SELECT
        vw_rtv_shipment_picklist.rtv_shipment_id,
        vw_rtv_shipment_picklist.channel_id,
        vw_rtv_shipment_picklist.sales_channel,
        vw_rtv_shipment_picklist.rtv_shipment_status_id,
        vw_rtv_shipment_picklist.rtv_shipment_status,
        vw_rtv_shipment_picklist.location,
        vw_rtv_shipment_picklist.loc_dc,
        vw_rtv_shipment_picklist.loc_floor,
        vw_rtv_shipment_picklist.loc_zone,
        vw_rtv_shipment_picklist.loc_section,
        vw_rtv_shipment_picklist.loc_shelf,
        vw_rtv_shipment_picklist.quantity_status_id,
        vw_rtv_shipment_picklist.sku,
        sum(vw_rtv_shipment_picklist.rtv_shipment_detail_quantity) AS sum_picklist_quantity
      FROM
        vw_rtv_shipment_picklist
      WHERE
        (vw_rtv_shipment_picklist.rtv_shipment_status)::text = ANY (
          (ARRAY['New'::character varying, 'Picking'::character varying])::text[]
        )
      GROUP BY
        vw_rtv_shipment_picklist.rtv_shipment_id,
        vw_rtv_shipment_picklist.channel_id,
        vw_rtv_shipment_picklist.sales_channel,
        vw_rtv_shipment_picklist.rtv_shipment_status_id,
        vw_rtv_shipment_picklist.rtv_shipment_status,
        vw_rtv_shipment_picklist.sku,
        vw_rtv_shipment_picklist.location,
        vw_rtv_shipment_picklist.loc_dc,
        vw_rtv_shipment_picklist.loc_floor,
        vw_rtv_shipment_picklist.loc_zone,
        vw_rtv_shipment_picklist.loc_section,
        vw_rtv_shipment_picklist.loc_shelf,
        vw_rtv_shipment_picklist.quantity_status_id
     ) a
    LEFT JOIN
     (SELECT
        rtv_shipment_pick.rtv_shipment_id,
        rtv_shipment_pick.location,
        rtv_shipment_pick.sku,
        count(*) AS picked_quantity
      FROM
        rtv_shipment_pick
      WHERE
        rtv_shipment_pick.cancelled IS NULL
      GROUP BY
        rtv_shipment_pick.rtv_shipment_id,
        rtv_shipment_pick.sku,
        rtv_shipment_pick.location
     ) b
     ON a.sku = b.sku AND (a.location)::text = (b.location)::text AND a.rtv_shipment_id = b.rtv_shipment_id
;

ALTER TABLE vw_rtv_shipment_validate_pick OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_shipment_validate_pick TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_validate_pick TO perlydev;
GRANT ALL ON TABLE vw_rtv_shipment_validate_pick TO www;
ALTER TABLE vw_rtv_shipment_picklist OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_shipment_picklist TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_picklist TO perlydev;
GRANT ALL ON TABLE vw_rtv_shipment_picklist TO www;
ALTER TABLE vw_rtv_inspection_validate_pick OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_inspection_validate_pick TO postgres;
GRANT SELECT ON TABLE vw_rtv_inspection_validate_pick TO perlydev;
GRANT ALL ON TABLE vw_rtv_inspection_validate_pick TO www;
ALTER TABLE vw_rtv_inspection_list OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_inspection_list TO postgres;
GRANT SELECT ON TABLE vw_rtv_inspection_list TO perlydev;
GRANT ALL ON TABLE vw_rtv_inspection_list TO www;
ALTER TABLE vw_rtv_inspection_pick_requested OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_inspection_pick_requested TO postgres;
GRANT SELECT ON TABLE vw_rtv_inspection_pick_requested TO perlydev;
GRANT ALL ON TABLE vw_rtv_inspection_pick_requested TO www;
ALTER TABLE vw_rtv_inspection_pick_request_details OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_inspection_pick_request_details TO postgres;
GRANT SELECT ON TABLE vw_rtv_inspection_pick_request_details TO perlydev;
GRANT ALL ON TABLE vw_rtv_inspection_pick_request_details TO www;
ALTER TABLE vw_rtv_shipment_details_with_results OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_shipment_details_with_results TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_details_with_results TO perlydev;
GRANT ALL ON TABLE vw_rtv_shipment_details_with_results TO www;
ALTER TABLE vw_rtv_shipment_details OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_shipment_details TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_details TO perlydev;
GRANT ALL ON TABLE vw_rtv_shipment_details TO www;
ALTER TABLE vw_rma_request_details OWNER TO postgres;
GRANT ALL ON TABLE vw_rma_request_details TO postgres;
GRANT SELECT ON TABLE vw_rma_request_details TO perlydev;
GRANT ALL ON TABLE vw_rma_request_details TO www;
ALTER TABLE vw_rtv_workstation_stock OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_workstation_stock TO postgres;
GRANT SELECT ON TABLE vw_rtv_workstation_stock TO perlydev;
GRANT ALL ON TABLE vw_rtv_workstation_stock TO www;
ALTER TABLE vw_rtv_inspection_stock OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_inspection_stock TO postgres;
GRANT SELECT ON TABLE vw_rtv_inspection_stock TO perlydev;
GRANT ALL ON TABLE vw_rtv_inspection_stock TO www;
ALTER TABLE vw_rtv_stock_details OWNER TO postgres;
GRANT ALL ON TABLE vw_rtv_stock_details TO postgres;
GRANT SELECT ON TABLE vw_rtv_stock_details TO perlydev;
GRANT ALL ON TABLE vw_rtv_stock_details TO www;
ALTER TABLE vw_location_details OWNER TO postgres;
GRANT ALL ON TABLE vw_location_details TO postgres;
GRANT SELECT ON TABLE vw_location_details TO perlydev;
GRANT ALL ON TABLE vw_location_details TO www;

COMMIT;

