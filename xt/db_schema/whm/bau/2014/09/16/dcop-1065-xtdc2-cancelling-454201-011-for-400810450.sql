BEGIN;

   -- this will allow it to be cancelled again
   delete from cancelled_item where shipment_item_id = 6860305;  

COMMIT;
