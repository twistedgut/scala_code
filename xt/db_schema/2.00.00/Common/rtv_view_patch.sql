BEGIN;

DROP VIEW IF EXISTS vw_rtv_shipment_validate_pack;
DROP VIEW IF EXISTS vw_rtv_shipment_packlist;

CREATE VIEW vw_rtv_shipment_packlist AS
    SELECT rs.id AS rtv_shipment_id, rs.status_id AS rtv_shipment_status_id, rss.status AS rtv_shipment_status, rs.date_time AS rtv_shipment_date, to_char(rs.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_shipment_date, rsd.status_id AS rtv_shipment_detail_status_id, rsds.status AS rtv_shipment_detail_status, rsd.quantity AS rtv_shipment_detail_quantity, rr.id AS rma_request_id, rr.status_id AS rma_request_status_id, rr.date_request, to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_request, rrd.status_id AS rma_request_detail_status_id, rrd.fault_description, vw_pv.designer, vw_pv.sku, vw_pv.name, vw_pv.description, vw_pv.designer_size, vw_pv.colour, ift.fault_type
   FROM rtv_shipment rs
   JOIN rtv_shipment_status rss ON rs.status_id = rss.id
   JOIN rtv_shipment_detail rsd ON rsd.rtv_shipment_id = rs.id
   JOIN rtv_shipment_detail_status rsds ON rsd.status_id = rsds.id
   JOIN rma_request_detail rrd ON rrd.id = rsd.rma_request_detail_id
   JOIN vw_product_variant vw_pv ON rrd.variant_id = vw_pv.variant_id AND vw_pv.channel_id = rs.channel_id
   JOIN item_fault_type ift ON rrd.fault_type_id = ift.id
   JOIN rma_request rr ON rrd.rma_request_id = rr.id;

   GRANT ALL ON vw_rtv_shipment_packlist TO www;


   CREATE VIEW vw_rtv_shipment_validate_pack AS 
    SELECT a.rtv_shipment_id, a.rtv_shipment_status_id, a.rtv_shipment_status, a.sku, a.sum_packlist_quantity, COALESCE(b.packed_quantity, 0::bigint) AS packed_quantity, a.sum_packlist_quantity - COALESCE(b.packed_quantity, 0::bigint) AS remaining_to_pack
   FROM ( SELECT vw_rtv_shipment_packlist.rtv_shipment_id, vw_rtv_shipment_packlist.rtv_shipment_status_id, vw_rtv_shipment_packlist.rtv_shipment_status, vw_rtv_shipment_packlist.sku, sum(vw_rtv_shipment_packlist.rtv_shipment_detail_quantity) AS sum_packlist_quantity
           FROM vw_rtv_shipment_packlist
          WHERE vw_rtv_shipment_packlist.rtv_shipment_status::text = ANY (ARRAY['Picked'::character varying, 'Packing'::character varying]::text[])
          GROUP BY vw_rtv_shipment_packlist.rtv_shipment_id, vw_rtv_shipment_packlist.rtv_shipment_status_id, vw_rtv_shipment_packlist.rtv_shipment_status, vw_rtv_shipment_packlist.sku) a
   LEFT JOIN ( SELECT rtv_shipment_pack.rtv_shipment_id, rtv_shipment_pack.sku, count(*) AS packed_quantity
           FROM rtv_shipment_pack
          WHERE rtv_shipment_pack.cancelled IS NULL
          GROUP BY rtv_shipment_pack.rtv_shipment_id, rtv_shipment_pack.sku) b ON a.sku = b.sku::text AND a.rtv_shipment_id = b.rtv_shipment_id;

    GRANT ALL ON vw_rtv_shipment_validate_pack TO www;


COMMIT;