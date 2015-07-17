BEGIN;

UPDATE cancelled_item SET adjusted = 1 WHERE shipment_item_id IN (SELECT id FROM shipment_item WHERE shipment_id IN (SELECT shipment_id FROM link_stock_transfer__shipment));

COMMIT;