-- Purpose:
--  Create new tables for Finance Fraud Checking Hotlist

BEGIN;

-- new flag
insert into flag values (44, 'Hotlist', 2);

-- Create a subsection 'Fraud Hotlist' of section 'Finance'
INSERT INTO "authorisation_sub_section" (authorisation_section_id, sub_section) VALUES ((SELECT id FROM authorisation_section WHERE section='Finance'), 'Fraud Hotlist');

create table hotlist_type (
	id serial primary key, 
	type varchar(255) NOT NULL
	);

grant all on hotlist_type to www;
grant all on hotlist_type_id_seq to www;

insert into hotlist_type values (1, 'Address');
insert into hotlist_type values (2, 'Customer');
insert into hotlist_type values (3, 'Payment');


create table hotlist_field (
	id serial primary key, 
	hotlist_type_id integer references hotlist_type(id) NOT NULL,
	field varchar(255) NOT NULL
	);

grant all on hotlist_field to www;
grant all on hotlist_field_id_seq to www;

insert into hotlist_field values (1, 1, 'Street Address');
insert into hotlist_field values (2, 1, 'Town/City');
insert into hotlist_field values (3, 1, 'County/State');
insert into hotlist_field values (4, 1, 'Postcode/Zipcode');
insert into hotlist_field values (5, 1, 'Country');
insert into hotlist_field values (6, 2, 'Email');
insert into hotlist_field values (7, 2, 'Telephone');
insert into hotlist_field values (8, 3, 'Card Number');


create table hotlist_value (
	id serial primary key, 
	hotlist_field_id integer references hotlist_field(id) NOT NULL,
	value varchar(255) NOT NULL
	);

grant all on hotlist_value to www;
grant all on hotlist_value_id_seq to www;


-- Do it!
COMMIT;
