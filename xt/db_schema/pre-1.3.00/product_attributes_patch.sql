-- Purpose:


BEGIN;

-- Create product department lookup table
create table product_department (
	id serial primary key, 
	department varchar(255) NOT NULL
	);

grant all on product_department to www;
grant all on product_department_id_seq to www;

-- pre populate product_department table
insert into product_department values (0, 'Unknown'); 
insert into product_department values (1, 'Accessories'); 
insert into product_department values (2, 'Bridge'); 
insert into product_department values (3, 'Casualwear'); 
insert into product_department values (4, 'Contemporary'); 
insert into product_department values (5, 'Designer'); 
insert into product_department values (6, 'Jewelry'); 
insert into product_department values (7, 'LAB'); 
insert into product_department values (8, 'Shoes'); 
insert into product_department values (9, 'Superbrand'); 
insert into product_department values (10, 'Swimwear'); 


-- adding new fields to product_attribute to store but sheet info
alter table product_attribute add column runway_look varchar(255) null;
alter table product_attribute add column sample_correct boolean default false;
alter table product_attribute add column sample_colour_correct boolean default false;
alter table product_attribute add column product_department_id integer references product_department(id) not null default 0;


-- Create shipment window type lookup table
create table shipment_window_type (
	id serial primary key, 
	type varchar(255) NOT NULL
	);

grant all on shipment_window_type to www;
grant all on shipment_window_type_id_seq to www;

-- pre populate shipment_window_type table
insert into shipment_window_type values (0, 'Unknown'); 
insert into shipment_window_type values (1, 'Ex Factory'); 
insert into shipment_window_type values (2, 'Landed'); 

-- adding new shipment_window_type field to stock_order table
alter table stock_order add column shipment_window_type_id integer references shipment_window_type(id) not null default 0;


-- adding placed by operator to purchase_order table
alter table purchase_order add column placed_by varchar(255) null;



-- Do it!
COMMIT;
