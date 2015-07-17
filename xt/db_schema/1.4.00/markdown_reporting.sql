-- Purpose:
--  

BEGIN;


-- Create lookup table for markdown categories
create table price_adjustment_category (
	id serial primary key, 
	category varchar(255) NOT NULL
	);

grant all on price_adjustment_category to www;
grant all on price_adjustment_category_id_seq to www;

-- populate table
insert into price_adjustment_category values (0, 'None');
insert into price_adjustment_category values (1, '1st MD');
insert into price_adjustment_category values (2, '2nd MD');
insert into price_adjustment_category values (3, '3rd MD');
insert into price_adjustment_category values (4, '4th MD');
insert into price_adjustment_category values (5, '5th MD');
insert into price_adjustment_category values (6, '6th MD');
insert into price_adjustment_category values (7, '7th MD');
insert into price_adjustment_category values (50, 'Mid Season');
insert into price_adjustment_category values (100, 'Clearance');


-- add finish date to price adjustment table
alter table price_adjustment add column date_finish timestamp default '2100-01-01';

-- add new category to price adjustment table
alter table price_adjustment add column category_id integer references price_adjustment_category(id) not null default 0;


-- add some indexes as we're date matching a lot now
create index price_adj_start on price_adjustment(date_start);
create index price_adj_end on price_adjustment(date_finish);


-- Create link table for markdown to shipment item
create table link_shipment_item__price_adjustment (
	shipment_item_id integer references shipment_item(id) not null,
	price_adjustment_id integer references price_adjustment(id) not null,
	CONSTRAINT ship_item_adjustment UNIQUE(shipment_item_id)
	);

grant all on link_shipment_item__price_adjustment to www;


COMMIT;