-- Purpose:
--  

BEGIN;


-- Add constraint to customer table
alter table customer add constraint customer_category_id foreign key (category_id) references customer_category(id);

-- get rid of old categories
delete from customer_category where category = 'empty';
delete from customer_category where category = 'empty2';
delete from customer_category where category = 'empty 3';
delete from customer_category where category = 'No shipping transient';
delete from customer_category where category = 'BarclaysFashionShow';
delete from customer_category where category = 'Carmen''s Event';

-- rename RCustomer to something more sensible
update customer_category set category = 'None' where category = 'RCustomer';

COMMIT;