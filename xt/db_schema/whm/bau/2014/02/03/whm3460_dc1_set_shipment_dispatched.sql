BEGIN;

    -- Update shipment_status
    UPDATE shipment
        SET shipment_status_id=(
            SELECT id FROM shipment_status WHERE status='Dispatched')
        WHERE id in(4842779);
    
    -- Update the logs
    INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id)
    SELECT id,
       (SELECT id FROM shipment_status WHERE status='Dispatched'),
          (SELECT id FROM operator WHERE name='Application')  
    FROM shipment WHERE id in(4842779);
    
    -- Update shipment_item_status
    UPDATE shipment_item
        SET shipment_item_status_id=
           (SELECT id FROM shipment_item_status WHERE status='Dispatched')
        WHERE shipment_id in(4842779);
        
    -- Update the logs, possibly multiple copies
    INSERT INTO shipment_item_status_log(shipment_item_id, shipment_item_status_id, operator_id)
    SELECT id,
       (SELECT id FROM shipment_item_status WHERE status='Dispatched'),
          (SELECT id FROM operator WHERE name='Application')  
    FROM shipment_item WHERE shipment_id in(4842779);

    -- Update order status
    update orders set order_status_id = (select id from order_status where status='Accepted')
    where id = (select orders_id from link_orders__shipment  where shipment_id = 4842779);

COMMIT;
