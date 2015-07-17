BEGIN;

    DELETE FROM rtv_shipment_detail_status_log WHERE rtv_shipment_detail_id IN (
        SELECT rsd.id
        FROM rtv_shipment rs
        JOIN rtv_shipment_detail rsd ON (rs.id = rsd.rtv_shipment_id)
        JOIN rma_request_detail rrd ON (rsd.rma_request_detail_id = rrd.id)
        JOIN variant v ON (rrd.variant_id = v.id)
        LEFT OUTER JOIN rtv_quantity rq ON (rrd.rtv_quantity_id = rq.id)
        WHERE rq.id IS NULL
        AND rs.status_id = (SELECT id FROM rtv_shipment_status WHERE status = 'Picking')
    );

    DELETE FROM rtv_shipment_detail WHERE id IN (
        SELECT rsd.id
        FROM rtv_shipment rs
        JOIN rtv_shipment_detail rsd ON (rs.id = rsd.rtv_shipment_id)
        JOIN rma_request_detail rrd ON (rsd.rma_request_detail_id = rrd.id)
        JOIN variant v ON (rrd.variant_id = v.id)
        LEFT OUTER JOIN rtv_quantity rq ON (rrd.rtv_quantity_id = rq.id)
        WHERE rq.id IS NULL
        AND rs.status_id = (SELECT id FROM rtv_shipment_status WHERE status = 'Picking')
    );

COMMIT;