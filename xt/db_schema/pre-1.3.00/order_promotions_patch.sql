-- Purpose:
--  create new promotion class table and update existing promtion type table to cater for revamped promotion system

BEGIN;


-- Create promotion class table
create table promotion_class (
	id serial primary key, 
	class varchar(255) NOT NULL
	);
 -- sort out permissions
grant all on promotion_class to www;
grant all on promotion_class_id_seq to www;

-- populate it
insert into promotion_class values (default, 'Money Off');
insert into promotion_class values (default, 'Free Gift');

-- add extra fields to promotion type
alter table promotion_type add column product_type varchar(255) null;
alter table promotion_type add column weight decimal(10,2) null;
alter table promotion_type add column fabric varchar(255) null;
alter table promotion_type add column origin varchar(255) null;
alter table promotion_type add column hs_code varchar(255) null;
alter table promotion_type add column promotion_class_id integer references promotion_class(id) null;

-- populate promotion class field on existing promotion types
update promotion_type set promotion_class_id = 1 where id in (1,2);

-- create promo type for the Notes Free Gift promo
insert into promotion_type values (3, 'NET-A-PORTER Notes', 'Diary Notebook', 0.1, '100% paper', 'United Kingdom', '482010', 2);
insert into promotion_type values (4, 'NET-A-PORTER Pen', 'Pen', 0.1, 'Plastic ball point pen', 'Italy', '960810', 2);


COMMIT;