-- DCOP-146 Remove log_delivery entry

BEGIN;
    DELETE FROM log_delivery
        WHERE operator_id = ( SELECT id FROM operator WHERE name = 'Nathan Silvera' )
        AND delivery_id = 2327817
        AND delivery_action_id = ( SELECT id FROM delivery_action WHERE action = 'Count' )
        AND quantity > 1000000
    ;
COMMIT;
