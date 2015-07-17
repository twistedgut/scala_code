-- Purpose:
--  

BEGIN;


-- Create table for duty rules
create table duty_rule (
	id serial primary key, 
	rule varchar(255) NOT NULL
	);

grant all on duty_rule to www;
grant all on duty_rule_id_seq to www;

insert into duty_rule values (1, 'Product Percentage');
insert into duty_rule values (2, 'Order Threshold');
insert into duty_rule values (3, 'Fixed Rate');

-- Create table for duty rule values
create table duty_rule_value (
	id serial primary key, 
	duty_rule_id integer references duty_rule(id) NOT NULL,
	country_id integer references country(id) NOT NULL,
	value integer NOT NULL
	);

grant all on duty_rule_value to www;
grant all on duty_rule_value_id_seq to www;

insert into duty_rule_value values (1, 1, (select id from country where country='Japan'), 60);
insert into duty_rule_value values (2, 2, (select id from country where country='Australia'), 400);
insert into duty_rule_value values (3, 3, (select id from country where country='Switzerland'), 5);


COMMIT;