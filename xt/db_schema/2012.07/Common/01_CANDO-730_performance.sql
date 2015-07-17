-- part of CANDO-706: Add indexes etc. to increase performance

BEGIN WORK;

-- CANDO-730: Query: stock_order_item has no index on voucher_variant_id
-- add index on foreign key that we come in on

CREATE 
 INDEX stock_order_item_voucher_variant_id_fkey
    ON stock_order_item(voucher_variant_id)
     ;

COMMIT WORK;
