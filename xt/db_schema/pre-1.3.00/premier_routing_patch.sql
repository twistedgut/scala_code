-- Purpose:
--  Create/Amend tables to incorporate DBS Premier Routing software

BEGIN;

-- new sections in Navigation
insert into authorisation_sub_section values (default, 2, 'Premier Routing');


-- Create routing export status lookup table
create table routing_export_status (
	id serial primary key, 
	status varchar(255) NOT NULL
	);

grant all on routing_export_status to www;
grant all on routing_export_status_id_seq to www;

-- pre populate manifest status
insert into routing_export_status values (1, 'Exporting');
insert into routing_export_status values (2, 'Exported');
insert into routing_export_status values (3, 'Complete');
insert into routing_export_status values (4, 'Cancelled');


-- Create table to store routing export details
create table routing_export (
	id serial primary key, 
	filename varchar(255) NOT NULL,
	cut_off timestamp NOT NULL,
	status_id integer references routing_export_status(id) NOT NULL
	);

grant all on routing_export to www;
grant all on routing_export_id_seq to www;

-- Create table to link shipments to routing export
create table link_routing_export__shipment (
	routing_export_id integer references routing_export(id) NOT NULL,
	shipment_id integer references shipment(id) NOT NULL	
	);

grant all on link_routing_export__shipment to www;

-- Create table to link returns to routing export
create table link_routing_export__return (
	routing_export_id integer references routing_export(id) NOT NULL,
	return_id integer references return(id) NOT NULL	
	);

grant all on link_routing_export__shipment to www;


-- Create table to log routing export status changes
create table routing_export_status_log (
	id serial primary key, 
	routing_export_id integer references routing_export(id) NOT NULL,
	status_id integer references routing_export_status(id) NOT NULL,
	operator_id integer references operator(id) NOT NULL,
	date timestamp NOT NULL
	);

grant all on routing_export_status_log to www;
grant all on routing_export_status_log_id_seq to www;

-- Do it!
COMMIT;
