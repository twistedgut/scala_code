-- CANDO-74 -  

BEGIN;

-- Add recipient email id for virtual vouchers to shipment_item table 
alter table shipment_item add column gift_recipient_email varchar(255); 

COMMIT;

