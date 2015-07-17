 BEGIN WORK;
 
 DROP VIEW vw_rma_request_details;

 CREATE VIEW vw_rma_request_details AS
     SELECT rr.id AS rma_request_id, rr.channel_id, 
         ch.name AS sales_channel, rr.operator_id, op.name AS operator_name, op.email_address, 
         rr.status_id AS rma_request_status_id, rrs.status AS rma_request_status, 
         rr.date_request, to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_request, 
         rr.date_followup, to_char(rr.date_followup, 'DD-Mon-YYYY'::text) AS txt_date_followup, rr.rma_number,   
         rr.comments AS rma_request_comments, rrd.id AS rma_request_detail_id, rrd.rtv_quantity_id,
         p.id as product_id, v.size_id, (v.product_id::text || '-'::text) || sku_padding(v.size_id)::text AS sku, curr.currency AS wholesale_currency,
         pp.original_wholesale, v.id AS variant_id,
         p.designer_id, d.designer, p.season_id, s.season, p.style_number, col.colour, pa.designer_colour_code, pa.designer_colour, 
         pa.name, pa.description, sz.size, dsz.size AS designer_size, nsz.nap_size, pt.product_type,
         rrd.delivery_item_id, dit.type AS delivery_item_type, del.date AS delivery_date, to_char(del.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date,
         rrd.quantity AS rma_request_detail_quantity, ift.fault_type, rrd.fault_description, rrdt.id AS rma_request_detail_type_id, 
         rrdt.type AS rma_request_detail_type, rrds.id AS rma_request_detail_status_id, rrds.status AS rma_request_detail_status, 
         rq.quantity AS rtv_stock_detail_quantity, l.location,
         substring(location from 1 for 2) AS loc_dc, 
         substring(location from 3 for 1) AS loc_floor, 
         substring(location from 4 for 1) AS loc_zone, 
         substring(location from 5 for 3) AS loc_section,
         substring(location from 8 for 1) AS loc_shelf, 
         rq.status_id AS quantity_status_id
    FROM rma_request                rr
    JOIN channel                    ch      ON rr.channel_id = ch.id
    JOIN rma_request_status         rrs     ON rr.status_id = rrs.id
    JOIN operator                   op      ON rr.operator_id = op.id
    JOIN rma_request_detail         rrd     ON rrd.rma_request_id = rr.id
    JOIN rma_request_detail_type    rrdt    ON rrd.type_id = rrdt.id
    JOIN item_fault_type            ift     ON rrd.fault_type_id = ift.id
    JOIN rma_request_detail_status  rrds    ON rrd.status_id = rrds.id
    left JOIN rtv_quantity          rq      on rrd.rtv_quantity_id = rq.id 
    left   JOIN location            l       ON rq.location_id = l.id 
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
    left JOIN delivery_item         di      ON rrd.delivery_item_id = di.id 
    left JOIN delivery_item_type    dit     ON di.type_id = dit.id 
    left JOIN delivery              del     ON di.delivery_id = del.id; 

GRANT ALL ON TABLE vw_rma_request_details TO www;
GRANT SELECT ON TABLE vw_rma_request_details TO perlydev;
GRANT ALL ON TABLE vw_rma_request_details TO postgres;


COMMIT WORK;
