-- Remove duplicate faulty PGIDs

BEGIN;

  -- First PGID (2209634)
  -- Update the delivery's status and log your change
  UPDATE delivery
    SET status_id = ( SELECT id FROM delivery_status WHERE status = 'Complete' )
    WHERE id = ( SELECT delivery_id FROM delivery_item WHERE id = ( SELECT delivery_item_id FROM stock_process WHERE group_id = 2209634 ) );
  INSERT INTO log_delivery
    ( delivery_id, type_id, delivery_action_id, operator_id, quantity, notes )
  VALUES (
    ( SELECT delivery_id FROM delivery_item WHERE id = ( SELECT delivery_item_id FROM stock_process WHERE group_id = 2209634 ) ),
    ( SELECT type_id FROM stock_process WHERE group_id = 2209634 ),
    ( SELECT id FROM delivery_action WHERE action = 'Putaway Prep' ),
    ( SELECT id FROM operator where name = 'Application' ),
    ( SELECT quantity FROM stock_process WHERE group_id = 2209634 ),
    'Resolved due to duplicate PGID which has now been deleted - see DCOP-847 for details'
  );

  -- Update the delivery item's status
  UPDATE delivery_item
    SET status_id = ( SELECT id FROM delivery_item_status WHERE status = 'Complete' )
    WHERE id = ( SELECT delivery_item_id FROM stock_process WHERE group_id = 2209634 );

  -- Delete the group id
  DELETE FROM stock_process WHERE group_id = 2209634;

  -- Second PGID (2362667)
  -- Update the delivery's status and log your change
  UPDATE delivery
    SET status_id = ( SELECT id FROM delivery_status WHERE status = 'Complete' )
    WHERE id = ( SELECT delivery_id FROM delivery_item WHERE id = ( SELECT delivery_item_id FROM stock_process WHERE group_id = 2362667 ) );
  INSERT INTO log_delivery
    ( delivery_id, type_id, delivery_action_id, operator_id, quantity, notes )
  VALUES (
    ( SELECT delivery_id FROM delivery_item WHERE id = ( SELECT delivery_item_id FROM stock_process WHERE group_id = 2362667 ) ),
    ( SELECT type_id FROM stock_process WHERE group_id = 2362667 ),
    ( SELECT id FROM delivery_action WHERE action = 'Putaway Prep' ),
    ( SELECT id FROM operator where name = 'Application' ),
    ( SELECT quantity FROM stock_process WHERE group_id = 2362667 ),
    'Resolved due to duplicate PGID which has now been deleted - see DCOP-847 for details'
  );

  -- Update the delivery item's status
  UPDATE delivery_item
    SET status_id = ( SELECT id FROM delivery_item_status WHERE status = 'Complete' )
    WHERE id = ( SELECT delivery_item_id FROM stock_process WHERE group_id = 2362667 );

  -- Delete the group id
  DELETE FROM stock_process WHERE group_id = 2362667;

  -- Third PGID (2282585)
  -- Update the delivery's status and log your change
  UPDATE delivery
    SET status_id = ( SELECT id FROM delivery_status WHERE status = 'Complete' )
    WHERE id = ( SELECT delivery_id FROM delivery_item WHERE id = ( SELECT delivery_item_id FROM stock_process WHERE group_id = 2282585 ) );
  INSERT INTO log_delivery
    ( delivery_id, type_id, delivery_action_id, operator_id, quantity, notes )
  VALUES (
    ( SELECT delivery_id FROM delivery_item WHERE id = ( SELECT delivery_item_id FROM stock_process WHERE group_id = 2282585 ) ),
    ( SELECT type_id FROM stock_process WHERE group_id = 2282585 ),
    ( SELECT id FROM delivery_action WHERE action = 'Putaway Prep' ),
    ( SELECT id FROM operator where name = 'Application' ),
    ( SELECT quantity FROM stock_process WHERE group_id = 2282585 ),
    'Resolved due to duplicate PGID which has now been deleted - see DCOP-847 for details'
  );

  -- Update the delivery item's status
  UPDATE delivery_item
    SET status_id = ( SELECT id FROM delivery_item_status WHERE status = 'Complete' )
    WHERE id = ( SELECT delivery_item_id FROM stock_process WHERE group_id = 2282585 );

  -- Delete the group id
  DELETE FROM stock_process WHERE group_id = 2282585;
COMMIT;
