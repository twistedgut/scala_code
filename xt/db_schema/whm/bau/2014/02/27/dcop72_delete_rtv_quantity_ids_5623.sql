BEGIN;

DELETE FROM rtv_inspection_pick_request_detail 
WHERE rtv_inspection_pick_request_id = 5623 
AND rtv_quantity_id in ( 141848, 141849, 141850, 142068, 142069 );

COMMIT;
