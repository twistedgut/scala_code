-- Drop unused indices

BEGIN;
    DROP INDEX idx_shipment_mobile_telephone;
    DROP INDEX idx_orders_telephone;
    DROP INDEX idx_orders_mobile_telephone;
    DROP INDEX shipment_shipment_nr;
    DROP INDEX idx_shipment_telephone;
    DROP INDEX ix_sessions_created;
    DROP INDEX idx_return_item_return_airway_bill;
    DROP INDEX firstname_lastnamefirst_idx;
    DROP INDEX customer_firstname_idx;
    DROP INDEX firstnamefirst_lastname_idx;
    DROP INDEX product_legacy_sku_key;
    DROP INDEX price_adj_end;
    DROP INDEX product.ix_pws_sort_order__score;
    DROP INDEX product.pssf_product_id;
    DROP INDEX ix_rtv_shipment_pick__location;
    DROP INDEX ix_rtv_shipment_pick__sku;
    DROP INDEX ix_rtv_shipment_pack__sku;
    DROP INDEX print_log_document;
    DROP INDEX customer_lastname_idx;
    DROP INDEX price_adj_start;
COMMIT;
