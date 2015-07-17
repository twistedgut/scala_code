-- 'Revert' this shipment as samples can't be returned to customers, and get it
-- to go through the booking in process. The logic is taken from
-- http://jira.nap/browse/DCOP-473

BEGIN;
    UPDATE shipment_item
        SET shipment_item_status_id = ( SELECT id FROM shipment_item_status WHERE status = 'Return Pending' )
        WHERE id = 5120243;
    INSERT INTO shipment_item_status_log
        ( shipment_item_id, shipment_item_status_id, operator_id )
    VALUES (
        5120243,
        ( SELECT id FROM shipment_item_status WHERE status = 'Return Pending' ),
        ( SELECT id FROM operator WHERE name = 'Application' )
    );

    UPDATE return_item
        SET return_item_status_id = ( SELECT id FROM return_item_status WHERE status = 'Awaiting Return' )
        WHERE shipment_item_id = 5120243;
    INSERT INTO return_item_status_log
        ( return_item_id, return_item_status_id, operator_id )
    VALUES (
        ( SELECT id FROM return_item WHERE shipment_item_id = 5120243 ),
        ( SELECT id FROM return_item_status WHERE status = 'Awaiting Return' ),
        ( SELECT id FROM operator WHERE name = 'Application' )
    );
COMMIT
