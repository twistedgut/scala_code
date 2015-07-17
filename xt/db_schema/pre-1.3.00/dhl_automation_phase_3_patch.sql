-- Purpose:
--  Create/Amend tables for DHL Automation section

BEGIN;

-- new sections in Navigation
insert into authorisation_sub_section values (default, 2, 'Invalid Shipments');
insert into authorisation_sub_section values (default, 2, 'Manifest');
insert into authorisation_sub_section values (default, 2, 'Labelling');

-- create DHL waybill sequence for waybill number generation
CREATE SEQUENCE waybill_nr MINVALUE 370944200 MAXVALUE 370978599 START 370944200;
grant all on waybill_nr to www;

-- create DHL licence plate sequence for LP number generation
CREATE SEQUENCE licence_plate_nr MINVALUE 22633060160000 MAXVALUE 22633069999999 START 22633060160000;
grant all on licence_plate_nr to www;

-- add new field(s) to box table
ALTER TABLE box ADD COLUMN length numeric(10,2) NOT NULL default 0;
ALTER TABLE box ADD COLUMN width numeric(10,2) NOT NULL default 0;
ALTER TABLE box ADD COLUMN height numeric(10,2) NOT NULL default 0;
ALTER TABLE box ADD COLUMN label_id integer NULL;

-- populate box size fields
update box set length = 25, width= 20, height = 11, label_id = 1 where box = 'Box - Size 1';
update box set length = 36, width= 28, height = 13, label_id = 2 where box = 'Box - Size 2';
update box set length = 43, width= 33, height = 16.8, label_id = 3 where box = 'Box - Size 3';
update box set length = 55, width= 36, height = 25, label_id = 4 where box = 'Box - Size 4';
update box set length = 68, width= 53, height = 26, label_id = 5 where box = 'Box - Size 5';
update box set length = 44, width= 36, height = 30, label_id = 6 where box = 'Box - OLD Size 5';
update box set length = 18.5, width= 11, height = 25.5, label_id = 7 where box = 'Bag - XSmall';
update box set length = 35.5, width= 16, height = 25.5, label_id = 8 where box = 'Bag - Small';
update box set length = 48.5, width= 23, height = 38.5, label_id = 9 where box = 'Bag - Medium';
update box set length = 46.5, width= 23, height = 65.5, label_id = 10 where box = 'Bag - Large';


-- Create manifest status lookup table
create table manifest_status (
	id serial primary key, 
	status varchar(255) NOT NULL
	);

grant all on manifest_status to www;
grant all on manifest_status_id_seq to www;

-- pre populate manifest status
insert into manifest_status values (1, 'Exporting');
insert into manifest_status values (2, 'Exported');
insert into manifest_status values (3, 'Sending');
insert into manifest_status values (4, 'Sent');
insert into manifest_status values (5, 'Imported');
insert into manifest_status values (6, 'Failed');
insert into manifest_status values (7, 'Complete');
insert into manifest_status values (8, 'Cancelled');


-- Create table to store manifest details
create table manifest (
	id serial primary key, 
	filename varchar(255) NOT NULL,
	cut_off timestamp NOT NULL,
	status_id integer references manifest_status(id) NOT NULL
	);

grant all on manifest to www;
grant all on manifest_id_seq to www;

-- Create table to link shipments to manifests
create table link_manifest__shipment (
	manifest_id integer references manifest(id) NOT NULL,
	shipment_id integer references shipment(id) NOT NULL	
	);

grant all on link_manifest__shipment to www;


-- Create table to log manifest status changes
create table manifest_status_log (
	id serial primary key, 
	manifest_id integer references manifest(id) NOT NULL,
	status_id integer references shipment(id) NOT NULL,
	operator_id integer references operator(id) NOT NULL,
	date timestamp NOT NULL
	);

grant all on manifest_status_log to www;
grant all on manifest_status_log_id_seq to www;

-- Do it!
COMMIT;
