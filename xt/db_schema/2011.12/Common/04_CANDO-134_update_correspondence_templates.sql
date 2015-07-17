-- CANDO-134: temporary hoojamaflip to make DB testing possible
--            shouldn't be in the release, I reckon

BEGIN WORK;

UPDATE correspondence_templates
   SET content = REPLACE(content,'shipping_address.first_name','branded_salutation')
 WHERE id = 21
     ;

UPDATE correspondence_templates
   SET content = REPLACE(content,'invoice_address.first_name','branded_salutation')
 WHERE id BETWEEN 48 AND 51
     ;
 
COMMIT WORK;
