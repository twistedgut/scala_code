--
-- FLEX-606: add indexes for return item queries
--

BEGIN;

CREATE
 INDEX return_item_return_item_status_id_idx
    ON return_item (
         return_item_status_id
       )
     ;
    
COMMIT;
