-- update existing containers that contain packing exception items,
-- and that are not already in packing exception status,
-- so that they are now in packing exception status

BEGIN;

UPDATE container
   SET status_id=(SELECT id
                    FROM container_status
                   WHERE name='Packing Exception Items'
                 )
 WHERE id IN (
    SELECT container_id
      FROM shipment_item si
      JOIN shipment_item_status sis ON si.shipment_item_status_id=sis.id
     WHERE sis.status='Packing Exception'
   )
;

COMMIT;
