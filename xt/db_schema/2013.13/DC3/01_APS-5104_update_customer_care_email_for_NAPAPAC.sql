begin;

update localised_email_address 
 set email_address = 'customercareapac@net-a-porter.com' 
 where email_address = 'customercare.apac@net-a-porter.com';

commit;


