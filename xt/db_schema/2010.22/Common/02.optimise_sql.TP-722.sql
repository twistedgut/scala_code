-- http://jira.nap/browse/TP-722

BEGIN;
    CREATE INDEX shipment_item_shipment_item_status_id ON shipment_item(shipment_item_status_id);
COMMIT;
