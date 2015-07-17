BEGIN;

DROP VIEW IF EXISTS daily_shipping_total;
DROP VIEW IF EXISTS invoice_item_information;
DROP VIEW IF EXISTS product_summary;
DROP VIEW IF EXISTS shipment_item_information;
DROP VIEW IF EXISTS upload_product;
DROP VIEW IF EXISTS upload;
DROP VIEW IF EXISTS view_osp;
DROP VIEW IF EXISTS view_wearitwith;
DROP VIEW IF EXISTS vw_declined_completed_date;
DROP VIEW IF EXISTS vw_sale_orders;
DROP VIEW IF EXISTS view_product_upload;


--**** TBC ****
--vw_designer_rtv_address
--vw_designer_rtv_carrier
--vw_list_rma
--vw_location_details
--vw_rma_request_designers
--vw_rma_request_details
--vw_rma_request_notes
--vw_rtv_address
--vw_rtv_inspection_list
--vw_rtv_inspection_pick_request_details
--vw_rtv_inspection_pick_requested
--vw_rtv_inspection_stock
--vw_rtv_inspection_validate_pick
--vw_rtv_quantity
--vw_rtv_quantity_check
--vw_rtv_shipment_detail_result_totals
--vw_rtv_shipment_detail_result_totals_row
--vw_rtv_shipment_details
--vw_rtv_shipment_details_with_results
--vw_rtv_shipment_packlist
--vw_rtv_shipment_picklist
--vw_rtv_shipment_validate_pack
--vw_rtv_shipment_validate_pick
--vw_rtv_stock_designers
--vw_rtv_stock_details
--vw_rtv_workstation_stock
--vw_stock_process

COMMIT;