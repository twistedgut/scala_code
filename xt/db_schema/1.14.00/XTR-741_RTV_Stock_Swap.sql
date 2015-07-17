/**************************************
* XTR-748: RTV - Add 'Stock Swap'
*
* Schema changes
* 
**************************************/

BEGIN;


INSERT INTO rma_request_detail_type (id, type) VALUES (4, 'Sale or Return');
INSERT INTO rma_request_detail_type (id, type) VALUES (5, 'Stock Swap');
SELECT setval('rma_request_detail_type_id_seq', (SELECT max(id) FROM rma_request_detail_type));



INSERT INTO rtv_shipment_detail_result_type (id, type) VALUES (5, 'Stock Swapped');
SELECT setval('rtv_shipment_detail_result_type_id_seq', (SELECT max(id) FROM rtv_shipment_detail_result_type));



DROP VIEW vw_rtv_shipment_details_with_results;
DROP VIEW vw_rtv_shipment_detail_result_totals_row;
DROP VIEW vw_rtv_shipment_detail_result_totals;


CREATE VIEW vw_rtv_shipment_detail_result_totals AS
    SELECT
        C.*,
        coalesce(D.sum_quantity, 0) AS total_quantity
    FROM
        (SELECT A.rtv_shipment_detail_id, B.type_id, B.type
        FROM
            (SELECT DISTINCT rtv_shipment_detail_id FROM rtv_shipment_detail_result) A
        CROSS JOIN
            (SELECT id AS type_id, type FROM rtv_shipment_detail_result_type) B ) C
    LEFT JOIN
        (SELECT
            rsdr.rtv_shipment_detail_id,
            rsdr.type_id,
            rsdrt.type,
            sum(quantity) AS sum_quantity
        FROM rtv_shipment_detail_result rsdr
        INNER JOIN rtv_shipment_detail_result_type rsdrt
            ON (rsdr.type_id = rsdrt.id)
        GROUP BY rsdr.rtv_shipment_detail_id, rsdr.type_id, rsdrt.type) D
        ON (C.rtv_shipment_detail_id = D.rtv_shipment_detail_id AND C.type_id = D.type_id)
;
GRANT SELECT ON vw_rtv_shipment_detail_result_totals TO www;


CREATE VIEW vw_rtv_shipment_detail_result_totals_row AS
    SELECT
        rtv_shipment_detail_id,
        SUM(CASE type WHEN 'Unknown' THEN total_quantity ELSE 0 END) AS unknown,
        SUM(CASE type WHEN 'Credited' THEN total_quantity ELSE 0 END) AS credited,
        SUM(CASE type WHEN 'Repaired' THEN total_quantity ELSE 0 END) AS repaired,
        SUM(CASE type WHEN 'Replaced' THEN total_quantity ELSE 0 END) AS replaced,
        SUM(CASE type WHEN 'Dead' THEN total_quantity ELSE 0 END) AS dead,
        SUM(CASE type WHEN 'Stock Swapped' THEN total_quantity ELSE 0 END) AS stock_swapped
    FROM vw_rtv_shipment_detail_result_totals
    GROUP BY rtv_shipment_detail_id
;
GRANT SELECT ON vw_rtv_shipment_detail_result_totals_row TO www;


CREATE VIEW vw_rtv_shipment_details_with_results AS
    SELECT 
        vw_rsd.*,
        coalesce(vw_rsdrtr.Unknown, 0) AS result_total_unknown,
        coalesce(vw_rsdrtr.Credited, 0) AS result_total_credited,
        coalesce(vw_rsdrtr.Repaired, 0) AS result_total_repaired,
        coalesce(vw_rsdrtr.Replaced, 0) AS result_total_replaced,
        coalesce(vw_rsdrtr.Dead, 0) AS result_total_dead,
        coalesce(vw_rsdrtr.Stock_Swapped, 0) AS result_total_stock_swapped
    FROM vw_rtv_shipment_details vw_rsd
    LEFT JOIN vw_rtv_shipment_detail_result_totals_row vw_rsdrtr
        ON (vw_rsdrtr.rtv_shipment_detail_id = vw_rsd.rtv_shipment_detail_id)
    ;
GRANT SELECT ON vw_rtv_shipment_details_with_results TO www;


COMMIT;
