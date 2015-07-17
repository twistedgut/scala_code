--
-- FLEX-606: add indexes for return status_log queries
--

BEGIN;

CREATE
 INDEX return_status_log_return_status_id_idx
    ON return_status_log (
         return_status_id
       )
     ;
    
COMMIT;
