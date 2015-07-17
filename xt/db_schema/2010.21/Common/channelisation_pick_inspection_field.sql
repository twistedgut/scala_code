BEGIN;

------------------------------------------------------------------------------
--                   change field to handle longer sku
------------------------------------------------------------------------------
    drop view vw_rtv_inspection_validate_pick;
    alter table rtv_inspection_pick alter column sku type text;
    create view vw_rtv_inspection_validate_pick AS
        SELECT a.rtv_inspection_pick_request_id, a.status_id, a.status, a.location, a.loc_dc, a.loc_floor, a.loc_zone, a.loc_section, a.loc_shelf, a.location_type, a.sku, a.sum_picklist_quantity, COALESCE(b.picked_quantity, 0::bigint) AS picked_quantity, a.sum_picklist_quantity - COALESCE(b.picked_quantity, 0::bigint) AS remaining_to_pick
        FROM ( SELECT vw_rtv_inspection_pick_request_details.rtv_inspection_pick_request_id, vw_rtv_inspection_pick_request_details.status_id, vw_rtv_inspection_pick_request_details.status, vw_rtv_inspection_pick_request_details.location, vw_rtv_inspection_pick_request_details.loc_dc, vw_rtv_inspection_pick_request_details.loc_floor, vw_rtv_inspection_pick_request_details.loc_zone, vw_rtv_inspection_pick_request_details.loc_section, vw_rtv_inspection_pick_request_details.loc_shelf, vw_rtv_inspection_pick_request_details.location_type, vw_rtv_inspection_pick_request_details.sku, sum(vw_rtv_inspection_pick_request_details.quantity) AS sum_picklist_quantity
        FROM vw_rtv_inspection_pick_request_details
        WHERE vw_rtv_inspection_pick_request_details.status::text = ANY (ARRAY['New'::character varying, 'Picking'::character varying]::text[])
        GROUP BY vw_rtv_inspection_pick_request_details.rtv_inspection_pick_request_id, vw_rtv_inspection_pick_request_details.status_id, vw_rtv_inspection_pick_request_details.status, vw_rtv_inspection_pick_request_details.sku, vw_rtv_inspection_pick_request_details.location, vw_rtv_inspection_pick_request_details.loc_dc, vw_rtv_inspection_pick_request_details.loc_floor, vw_rtv_inspection_pick_request_details.loc_zone, vw_rtv_inspection_pick_request_details.loc_section, vw_rtv_inspection_pick_request_details.loc_shelf, vw_rtv_inspection_pick_request_details.location_type) a
        LEFT JOIN ( SELECT rtv_inspection_pick.rtv_inspection_pick_request_id, rtv_inspection_pick.location, rtv_inspection_pick.sku, count(*) AS picked_quantity
        FROM rtv_inspection_pick
        WHERE rtv_inspection_pick.cancelled IS NULL
        GROUP BY rtv_inspection_pick.rtv_inspection_pick_request_id, rtv_inspection_pick.sku, rtv_inspection_pick.location) b ON a.sku = b.sku::text AND a.location::text = b.location::text AND a.rtv_inspection_pick_request_id = b.rtv_inspection_pick_request_id;
    grant all on vw_rtv_inspection_validate_pick to www;
COMMIT;
