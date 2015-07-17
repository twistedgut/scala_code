BEGIN WORK;

DROP VIEW vw_rtv_shipment_details_with_results;

DROP VIEW vw_rtv_shipment_details;

CREATE VIEW vw_rtv_shipment_details AS
    SELECT rs.id AS rtv_shipment_id, rs.channel_id, ch.name AS sales_channel, rs.designer_rtv_carrier_id, 
        rtv_c.name AS rtv_carrier_name,  drtv_c.account_ref AS carrier_account_ref,
        rs.designer_rtv_address_id, 
        drtv_a.contact_name, 
        rtv_a.address_line_1,  rtv_a.address_line_2, rtv_a.address_line_3, rtv_a.town_city, rtv_a.region_county,  
        rtv_a.postcode_zip, rtv_a.country,  rs.date_time AS rtv_shipment_date, 
        to_char(rs.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_shipment_date, 
        rs.status_id AS rtv_shipment_status_id, rss.status AS rtv_shipment_status, rs.airway_bill, 
        rma.id AS rma_request_id, rma.operator_id,  op.name AS operator_name, op.email_address,
        rma.status_id AS rma_request_status_id,
        rrs.status AS rma_request_status, rma.date_request, to_char(rma.date_request, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_request,
        rma.date_followup, to_char(rma.date_followup, 'DD-Mon-YYYY'::text) AS txt_date_followup,
        rma.rma_number, rma.comments AS rma_request_comments, rrd.id AS rma_request_detail_id, rrd.rtv_quantity_id, v.product_id,
        v.size_id,  (v.product_id::text || '-'::text) || sku_padding(v.size_id)::text AS sku,
        curr.currency AS wholesale_currency, pp.original_wholesale, v.id AS variant_id, p.designer_id,
        d.designer, p.season_id, s.season, p.style_number, col.colour, pa.designer_colour_code, pa.designer_colour, 
        pa.name, pa.description, sz.size, dsz.size AS designer_size, nsz.nap_size, pt.product_type,
        di.id AS delivery_item_id, dit.type AS delivery_item_type, del.date AS delivery_date, to_char(del.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date,
        rrd.quantity AS rma_request_detail_quantity,
        ift.fault_type, rrd.fault_description, rrdt.id AS rma_request_detail_type_id, rrdt.type AS rma_request_detail_type,
        rrd.status_id AS rma_request_detail_status_id, rrds.status AS rma_request_detail_status,
        rq.quantity AS rtv_stock_detail_quantity, l.location,
        substring(location from 1 for 2) AS loc_dc, 
        substring(location from 3 for 1) AS loc_floor, 
        substring(location from 4 for 1) AS loc_zone, 
        substring(location from 5 for 3) AS loc_section,
        substring(location from 8 for 1) AS loc_shelf, 
        rq.status_id AS quantity_status_id,
        rsd.id AS rtv_shipment_detail_id, rsd.quantity AS rtv_shipment_detail_quantity, rsd.status_id AS rtv_shipment_detail_status_id,
        rsds.status AS rtv_shipment_detail_status
    FROM rtv_shipment               rs
    JOIN rtv_shipment_status        rss     ON rs.status_id = rss.id
    JOIN rtv_shipment_detail        rsd     on rs.id = rsd.rtv_shipment_id
    JOIN rtv_shipment_detail_status rsds    ON rsd.status_id = rsds.id
    JOIN rma_request_detail         rrd     on rsd.rma_request_detail_id = rrd.id
    JOIN item_fault_type            ift     ON rrd.fault_type_id = ift.id
    JOIN rma_request_detail_status  rrds    ON rrd.status_id = rrds.id
    JOIN rma_request_detail_type    rrdt    ON rrd.type_id = rrdt.id
    JOIN rma_request                rma     on rrd.rma_request_id = rma.id
    JOIN operator                   op      ON rma.operator_id = op.id
    JOIN rma_request_status         rrs     ON rma.status_id = rrs.id
    JOIN variant                    v       on rrd.variant_id = v.id
    JOIN product                    p       on v.product_id = p.id
    JOIN product_type               pt      ON p.product_type_id = pt.id
    JOIN product_attribute          pa      ON p.id = pa.product_id
    JOIN price_purchase             pp      ON p.id = pp.product_id
    JOIN currency                   curr    ON pp.wholesale_currency_id = curr.id
    JOIN designer                   d       on p.designer_id = d.id
    JOIN season                     s       ON p.season_id = s.id 
    JOIN colour                     col     ON p.colour_id = col.id 
    left JOIN size                  sz      ON v.size_id = sz.id 
    left JOIN size                  dsz     ON v.designer_size_id = dsz.id 
    left JOIN nap_size              nsz     ON v.nap_size_id = nsz.id  
    left JOIN rtv_quantity          rq      on rrd.rtv_quantity_id = rq.id 
    left JOIN location              l       ON rq.location_id = l.id 
    left JOIN delivery_item         di      ON rrd.delivery_item_id = di.id 
    left JOIN delivery_item_type    dit     ON di.type_id = dit.id 
    left JOIN delivery              del     ON di.delivery_id = del.id 
    JOIN channel                    ch      ON rs.channel_id = ch.id 
    JOIN designer_rtv_address       drtv_a  ON rs.designer_rtv_address_id = drtv_a.id 
    JOIN rtv_address                rtv_a   ON drtv_a.rtv_address_id = rtv_a.id 
    JOIN designer_rtv_carrier       drtv_c  ON rs.designer_rtv_carrier_id = drtv_c.id 
    JOIN rtv_carrier                rtv_c   ON drtv_c.rtv_carrier_id = rtv_c.id; 

CREATE VIEW vw_rtv_shipment_details_with_results AS
    SELECT vw_rsd.rtv_shipment_id, vw_rsd.channel_id, ch.name AS sales_channel, vw_rsd.designer_rtv_carrier_id, vw_rsd.rtv_carrier_name, 
        vw_rsd.carrier_account_ref, vw_rsd.designer_rtv_address_id, vw_rsd.contact_name, vw_rsd.address_line_1, vw_rsd.address_line_2, vw_rsd.address_line_3,
        vw_rsd.town_city, vw_rsd.region_county, vw_rsd.postcode_zip, vw_rsd.country, vw_rsd.rtv_shipment_date, vw_rsd.txt_rtv_shipment_date,
        vw_rsd.rtv_shipment_status_id, vw_rsd.rtv_shipment_status, vw_rsd.airway_bill, vw_rsd.rma_request_id, vw_rsd.operator_id, vw_rsd.operator_name,
        vw_rsd.email_address, vw_rsd.rma_request_status_id, vw_rsd.rma_request_status, vw_rsd.date_request, vw_rsd.txt_date_request, vw_rsd.date_followup,
        vw_rsd.txt_date_followup, vw_rsd.rma_number, vw_rsd.rma_request_comments, vw_rsd.rma_request_detail_id, vw_rsd.rtv_quantity_id, vw_rsd.product_id,
        vw_rsd.size_id, vw_rsd.sku, vw_rsd.variant_id, vw_rsd.designer_id, vw_rsd.designer, vw_rsd.season_id, vw_rsd.season, vw_rsd.style_number, vw_rsd.colour,
        vw_rsd.designer_colour_code, vw_rsd.designer_colour, vw_rsd.name, vw_rsd.description, vw_rsd.size, vw_rsd.designer_size, vw_rsd.nap_size,
        vw_rsd.product_type, vw_rsd.delivery_item_id, vw_rsd.delivery_item_type, vw_rsd.delivery_date, vw_rsd.txt_delivery_date, vw_rsd.rma_request_detail_quantity,
        vw_rsd.fault_type, vw_rsd.fault_description, vw_rsd.rma_request_detail_type_id, vw_rsd.rma_request_detail_type, vw_rsd.rma_request_detail_status_id,
        vw_rsd.rma_request_detail_status, vw_rsd.rtv_stock_detail_quantity, vw_rsd.location, vw_rsd.loc_dc, vw_rsd.loc_floor, vw_rsd.loc_zone, vw_rsd.loc_section,
        vw_rsd.loc_shelf, vw_rsd.quantity_status_id, vw_rsd.rtv_shipment_detail_id, vw_rsd.rtv_shipment_detail_quantity,
        vw_rsd.rtv_shipment_detail_status_id, vw_rsd.rtv_shipment_detail_status,
        COALESCE(vw_rsdrtr.unknown, 0::numeric) AS result_total_unknown,
        COALESCE(vw_rsdrtr.credited, 0::numeric) AS result_total_credited,
        COALESCE(vw_rsdrtr.repaired, 0::numeric) AS result_total_repaired,
        COALESCE(vw_rsdrtr.replaced, 0::numeric) AS result_total_replaced,
        COALESCE(vw_rsdrtr.dead, 0::numeric) AS result_total_dead,
        COALESCE(vw_rsdrtr.stock_swapped, 0::numeric) AS result_total_stock_swapped
   FROM vw_rtv_shipment_details vw_rsd
   JOIN channel ch ON vw_rsd.channel_id = ch.id
   LEFT JOIN vw_rtv_shipment_detail_result_totals_row vw_rsdrtr ON vw_rsdrtr.rtv_shipment_detail_id = vw_rsd.rtv_shipment_detail_id;

GRANT ALL ON TABLE vw_rtv_shipment_details TO www;
GRANT SELECT ON TABLE vw_rtv_shipment_details TO perlydev;
GRANT ALL ON TABLE vw_rtv_shipment_details TO postgres;

GRANT ALL ON TABLE vw_rtv_shipment_details_with_results TO www;
GRANT SELECT ON TABLE vw_rtv_shipment_details_with_results TO perlydev;
GRANT ALL ON TABLE vw_rtv_shipment_details_with_results TO postgres;

COMMIT WORK;
