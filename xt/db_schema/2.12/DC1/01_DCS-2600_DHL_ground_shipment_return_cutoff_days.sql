-- Update the RMA window for DHL Ground shipments from DC1 from 12 days to 16 days 
BEGIN;
    UPDATE public.shipping_account
       SET return_cutoff_days=16
     WHERE name='Europlus International'
     ;
COMMIT;
