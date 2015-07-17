BEGIN;

-- RES-W107 Update shipment_item from cancel pending to cancelled

UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    )
    WHERE id in ( 6540894, 6434489, 6068381, 6412659, 5928807, 5814233, 6433137, 5889006, 5841266, 6376504, 5861983, 6452829, 6314558 )
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancel Pending'
    );

UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    )
    WHERE id = 6003238
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'New'
    );

INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id) VALUES 
    ( 6540894,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 6434489,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 6068381,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 6412659,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 5928807,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 5814233,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 6433137,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 5889006,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 5841266,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 6376504,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 5861983,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 6452829,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 6314558,
      (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
      (SELECT id FROM operator WHERE name = 'Application') ),
    ( 6003238,
      (SELECT id FROM shipment_item_status WHERE status = 'New'),
      (SELECT id FROM operator WHERE name = 'Application') );

COMMIT;
