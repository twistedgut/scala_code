-- Purpose:
--  Create/Amend tables for Shipping Account changes

BEGIN;

-- create table for shipping account numbers
create table shipping_account (
	id serial primary key,
	name varchar(255) NOT NULL,
	account_number varchar(255) NOT NULL
	);

grant all on shipping_account to www;
grant all on shipping_account_id_seq to www;


-- create shipping accounts
insert into shipping_account values (0, 'Unknown', '');
insert into shipping_account values (1, 'Domestic', '');
insert into shipping_account values (2, 'International', '');
insert into shipping_account values (3, 'FTBC', '');

-- add shipping account id to shipment table
alter table shipment add column shipping_account_id integer references shipping_account(id) NOT NULL default 0;

-- backfill new column
update shipment set shipping_account_id = 1 where shipment_type_id = 3;
update shipment set shipping_account_id = 2 where shipment_type_id = 4;
update shipment set shipping_account_id = 2 where shipment_type_id = 5;

-- add shipping account id to dhl tariff tables
alter table dhl_outbound_tariff add column shipping_account_id integer references shipping_account(id) NOT NULL default 0;
alter table dhl_inbound_tariff add column shipping_account_id integer references shipping_account(id) NOT NULL default 0;


-- new box entry for FTBC bag
insert into box values (25, 'FTBC Bag', 0.02, 0.62, true, 1, 1, 1, null);


-- new tariffs for FTBC account
alter table dhl_outbound_tariff drop constraint pk_tariff_weight;

alter table dhl_outbound_tariff add constraint tariff_zone_weight_shipping_account_id unique(tariff_zone, weight, shipping_account_id);

COMMIT;
