-- Purpose:
--  

BEGIN;


-- Create table for tax rules
create table tax_rule (
	id serial primary key, 
	rule varchar(255) NOT NULL
	);

grant all on tax_rule to www;
grant all on tax_rule_id_seq to www;

insert into tax_rule values (1, 'Product Percentage');
insert into tax_rule values (2, 'Order Threshold');
insert into tax_rule values (3, 'Fixed Rate');

-- Create table for tax rule values
create table tax_rule_value (
	id serial primary key, 
	tax_rule_id integer references tax_rule(id) NOT NULL,
	country_id integer references country(id) NOT NULL,
	value integer NOT NULL
	);

grant all on tax_rule_value to www;
grant all on tax_rule_value_id_seq to www;

insert into tax_rule_value values (1, 2, (select id from country where country='Australia'), 400);

COMMIT;