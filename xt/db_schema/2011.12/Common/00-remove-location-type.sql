
-- DCEA-1113: Remove location_type from the DB

BEGIN WORK;

-- Legacy back up of location?
DROP TABLE old_location;

-- Remove views here
DROP VIEW product.vw_available_to_sell;
DROP VIEW njiv_stock_by_location_variant;
DROP VIEW vw_rtv_quantity_check;
DROP VIEW vw_rtv_quantity;

-- Redo the vw_rtv_quantity view. The only change is removal of location_type
CREATE VIEW vw_rtv_quantity AS
    SELECT  rq.id, rq.channel_id, rq.variant_id, rq.location_id, rq.quantity,
            rq.delivery_item_id, rq.fault_type_id, rq.fault_description,
            rq.origin, rq.date_created, v.product_id, l.location,
            rq.status_id AS quantity_status_id,
            rrd.rma_request_id, rrd.id AS rma_request_detail_id,
            rrd.quantity AS rma_request_detail_quantity, rsd.rtv_shipment_id,
            rsd.id AS rtv_shipment_detail_id,
            rsd.quantity AS rtv_shipment_detail_quantity
        FROM rtv_quantity rq
        JOIN location l ON rq.location_id = l.id
        JOIN variant v ON rq.variant_id = v.id
        LEFT JOIN rma_request_detail rrd ON rrd.rtv_quantity_id = rq.id
        LEFT JOIN rtv_shipment_detail rsd ON rsd.rma_request_detail_id = rrd.id;
GRANT ALL    ON TABLE vw_rtv_quantity TO www;
GRANT SELECT ON TABLE vw_rtv_quantity TO perlydev;
GRANT ALL    ON TABLE vw_rtv_quantity TO postgres;

-- Remove the reference in `location`
ALTER TABLE location DROP COLUMN type_id;

-- Drop the table itself
DROP TABLE location_type;

COMMIT WORK;
