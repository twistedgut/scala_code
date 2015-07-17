BEGIN;
------------------------------------------------------------------------------
--                   change rtv_shipment_pick.sku to handle longer sku
------------------------------------------------------------------------------

DROP VIEW vw_rtv_shipment_validate_pick;

ALTER TABLE rtv_shipment_pick ALTER COLUMN sku TYPE text;

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
       a.location_type, 
       a.sku, 
       a.sum_picklist_quantity, 
       COALESCE(b.picked_quantity, 0::bigint) AS picked_quantity, 
       a.sum_picklist_quantity - COALESCE(b.picked_quantity, 0::bigint) AS remaining_to_pick
FROM ( 
 SELECT vw_rtv_shipment_picklist.rtv_shipment_id, 
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
            vw_rtv_shipment_picklist.location_type, 
            vw_rtv_shipment_picklist.sku, 
            SUM(vw_rtv_shipment_picklist.rtv_shipment_detail_quantity) AS sum_picklist_quantity
       FROM vw_rtv_shipment_picklist
      WHERE vw_rtv_shipment_picklist.rtv_shipment_status::text = ANY (ARRAY['New'::character varying, 'Picking'::character varying]::text[])
   GROUP BY vw_rtv_shipment_picklist.rtv_shipment_id, 
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
            vw_rtv_shipment_picklist.location_type
) a
LEFT JOIN ( 
 SELECT rtv_shipment_pick.rtv_shipment_id, 
            rtv_shipment_pick.location, 
            rtv_shipment_pick.sku, 
            count(*) AS picked_quantity
       FROM rtv_shipment_pick
      WHERE rtv_shipment_pick.cancelled IS NULL
   GROUP BY rtv_shipment_pick.rtv_shipment_id, 
            rtv_shipment_pick.sku, 
            rtv_shipment_pick.location
) b 
 ON a.sku = b.sku::text 
AND a.location::text = b.location::text 
AND a.rtv_shipment_id = b.rtv_shipment_id;

GRANT ALL ON vw_rtv_shipment_validate_pick TO www;

------------------------------------------------------------------------------
--                   change rtv_shipment_pack.sku to handle longer sku
------------------------------------------------------------------------------

DROP VIEW vw_rtv_shipment_validate_pack;

ALTER TABLE rtv_shipment_pack ALTER COLUMN sku TYPE text;

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
