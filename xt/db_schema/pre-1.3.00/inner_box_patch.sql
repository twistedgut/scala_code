-- Purpose:
--  Create/Amend tables for DHL Automation section

BEGIN;

-- Create inner_box table
create table inner_box (
	id serial primary key, 
	inner_box varchar(255) NOT NULL,
	sort_order integer NOT NULL UNIQUE,
	active boolean default true,
	outer_box_id integer references box(id) null
	);

grant all on inner_box to www;
grant all on inner_box_id_seq to www;

-- pre populate inner_box
insert into inner_box values (1, 'Black Box New 1', 1, true, 12); 
insert into inner_box values (2, 'Black Box New 2', 2, true, 13); 
insert into inner_box values (3, 'Black Box New 3', 3, true, 14);
insert into inner_box values (4, 'Black Box New 4', 4, true, 15); 
insert into inner_box values (5, 'Black Box New 5', 5, true, 16);
insert into inner_box values (6, 'No Black Box', 6, true, null);  
insert into inner_box values (7, 'Carrier Bag XS', 7, true, 21); 
insert into inner_box values (8, 'Carrier Bag S', 8, true, 22);
insert into inner_box values (9, 'Carrier Bag M', 9, true, 23);
insert into inner_box values (10, 'Carrier Bag L', 10, true, 24);  


-- add inner_box_id field to shipment_box table

alter table shipment_box add column inner_box_id integer references inner_box(id) null default null;

-- Do it!
COMMIT;
