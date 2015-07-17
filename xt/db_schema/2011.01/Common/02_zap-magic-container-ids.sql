BEGIN;

UPDATE shipment_item
   SET container_id = NULL
 WHERE container_id = 'M000000'
     ;

UPDATE orphan_item
   SET container_id = NULL
 WHERE container_id = 'M000000'
     ;

DELETE
  FROM container
 WHERE id = 'M000000'
     ;

COMMIT;
