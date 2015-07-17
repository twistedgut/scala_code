-- Purpose:
--  Create new tables for Perpetual Inventory section and add PI to navigation

BEGIN;

-- Create a subsection 'Perpetual Inventory' of section 'Stock Control'
INSERT INTO "authorisation_sub_section" (authorisation_section_id, sub_section) VALUES ((SELECT id FROM authorisation_section WHERE section='Stock Control'), 'Perpetual Inventory');

-- Create summary table for stock counting
create table stock_count_summary (
	id serial primary key, 
	start_date timestamp NOT NULL,
	end_date timestamp NOT NULL,
	counts_required integer NOT NULL,
	counts_completed integer NOT NULL,
	variances integer NOT NULL,
	stock_error numeric(10,2) NOT NULL
	);

grant all on stock_count_summary to www;
grant all on stock_count_summary_id_seq to www;

-- Create lookup for stock count categories
create table stock_count_category (
	id serial primary key, 
	category varchar(255) NOT NULL,
	priority integer NOT NULL
	);

grant all on stock_count_category to www;
grant all on stock_count_category_id_seq to www;

insert into stock_count_category values (1, 'A', 5);
insert into stock_count_category values (2, 'B', 4);
insert into stock_count_category values (3, 'C', 3);
insert into stock_count_category values (4, 'D', 2);
insert into stock_count_category values (5, 'Manual', 1);
insert into stock_count_category values (6, 'Miscellaneous', 0);

-- Create main table to hold required stock counts for the quarter
create table stock_count_variant (
	variant_id integer references variant(id) NOT NULL, 
	location_id integer references location(id) NOT NULL,
	stock_count_category_id integer references stock_count_category(id) NOT NULL,
	last_count timestamp NULL
	);

grant all on stock_count_variant to www;


-- Create lookup table for stock count status
create table stock_count_status (
	id serial primary key, 
	status varchar(255) NOT NULL
	);

grant all on stock_count_status to www;
grant all on stock_count_status_id_seq to www;

insert into stock_count_status values (default, 'Counted');
insert into stock_count_status values (default, 'Pending Investigation');
insert into stock_count_status values (default, 'Accepted');
insert into stock_count_status values (default, 'Declined');


create sequence stock_count_group start 1;

grant all on stock_count_group to www;


-- Create table to record stock counts
create table stock_count (
	id serial primary key, 	
	variant_id integer references variant(id) NOT NULL, 
	location_id integer references location(id) NOT NULL,
	group_id integer NOT NULL,
	date timestamp NOT NULL,
	operator_id integer references operator(id) NOT NULL,
	expected_quantity integer NOT NULL,
	counted_quantity integer NOT NULL,
	round integer NOT NULL,
	stock_count_status_id integer references stock_count_status(id) NOT NULL
	);

grant all on stock_count to www;
grant all on stock_count_id_seq to www;

COMMIT;

BEGIN WORK;

-- create new stock and pws actions for stock counting
insert into stock_action values (12, 'Stock Count');
insert into pws_action values (12, 'Stock Count');

-- Do it!
COMMIT;
