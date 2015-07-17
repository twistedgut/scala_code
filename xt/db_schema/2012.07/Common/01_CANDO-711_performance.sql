-- part of CANDO-706: Add indexes etc. to increase performance

BEGIN WORK;

-- CANDO-711: Goods In > Returns QC is too slow

CREATE 
 INDEX stock_process_type_id_idx 
    ON stock_process(type_id)
     ;

COMMIT WORK;
