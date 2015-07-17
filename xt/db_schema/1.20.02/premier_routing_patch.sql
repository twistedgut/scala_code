--Set all existing premier routing entries to 0

BEGIN;

    UPDATE shipment SET premier_routing_id = 0 WHERE shipment_type_id =
        ( SELECT id FROM shipment_type WHERE type='Premier' )
    ;

ROLLBACK;
