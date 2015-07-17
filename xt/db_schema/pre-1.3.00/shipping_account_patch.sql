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
insert into shipping_account values (1, 'Domestic', '135104716');
insert into shipping_account values (2, 'International', '133174304');
insert into shipping_account values (3, 'FTBC', '180275814');

-- add shipping account id to shipment table
alter table shipment add column shipping_account_id integer references shipping_account(id) NOT NULL default 0;

-- backfill new column
update shipment set shipping_account_id = 1 where shipment_type_id = 3;
update shipment set shipping_account_id = 2 where shipment_type_id = 4;
update shipment set shipping_account_id = 2 where shipment_type_id = 5;

-- add shipping account id to dhl tariff tables
alter table dhl_outbound_tariff add column shipping_account_id integer references shipping_account(id) NOT NULL default 0;
alter table dhl_inbound_tariff add column shipping_account_id integer references shipping_account(id) NOT NULL default 0;

-- backfill the new column
update dhl_outbound_tariff set shipping_account_id = 2;
update dhl_outbound_tariff set shipping_account_id = 1 where tariff_zone = 'DOM';


-- new box entry for FTBC bag
insert into box values (25, 'FTBC Bag', 0.02, 0.62, true, 1, 1, 1, null);


-- new tariffs for FTBC account
alter table dhl_outbound_tariff drop constraint pk_tariff_weight;

alter table dhl_outbound_tariff add constraint tariff_zone_weight_shipping_account_id unique(tariff_zone, weight, shipping_account_id);

insert into dhl_outbound_tariff values (1, 0.5, 6.38, 3);
insert into dhl_outbound_tariff values (1, 1, 8.77, 3);
insert into dhl_outbound_tariff values (1, 1.5, 9.38, 3);
insert into dhl_outbound_tariff values (1, 2, 10.5, 3);
insert into dhl_outbound_tariff values (1, 2.5, 11.18, 3);
insert into dhl_outbound_tariff values (1, 3, 11.79, 3);

insert into dhl_outbound_tariff values (2, 0.5, 6.91, 3);
insert into dhl_outbound_tariff values (2, 1, 9.21, 3);
insert into dhl_outbound_tariff values (2, 1.5, 10.18, 3);
insert into dhl_outbound_tariff values (2, 2, 11.76, 3);
insert into dhl_outbound_tariff values (2, 2.5, 12.84, 3);
insert into dhl_outbound_tariff values (2, 3, 13.81, 3);

insert into dhl_outbound_tariff values (3, 0.5, 7.84, 3);
insert into dhl_outbound_tariff values (3, 1, 10.56, 3);
insert into dhl_outbound_tariff values (3, 1.5, 11.85, 3);
insert into dhl_outbound_tariff values (3, 2, 13.85, 3);
insert into dhl_outbound_tariff values (3, 2.5, 15.28, 3);
insert into dhl_outbound_tariff values (3, 3, 16.61, 3);

insert into dhl_outbound_tariff values (4, 0.5, 8.11, 3);
insert into dhl_outbound_tariff values (4, 1, 10.87, 3);
insert into dhl_outbound_tariff values (4, 1.5, 12.17, 3);
insert into dhl_outbound_tariff values (4, 2, 14.19, 3);
insert into dhl_outbound_tariff values (4, 2.5, 15.63, 3);
insert into dhl_outbound_tariff values (4, 3, 16.98, 3);

insert into dhl_outbound_tariff values (5, 0.5, 10.04, 3);
insert into dhl_outbound_tariff values (5, 1, 11.67, 3);
insert into dhl_outbound_tariff values (5, 1.5, 12.77, 3);
insert into dhl_outbound_tariff values (5, 2, 14.63, 3);
insert into dhl_outbound_tariff values (5, 2.5, 15.85, 3);
insert into dhl_outbound_tariff values (5, 3, 16.90, 3);

insert into dhl_outbound_tariff values (6, 0.5, 11.61, 3);
insert into dhl_outbound_tariff values (6, 1, 13.89, 3);
insert into dhl_outbound_tariff values (6, 1.5, 15.11, 3);
insert into dhl_outbound_tariff values (6, 2, 17.18, 3);
insert into dhl_outbound_tariff values (6, 2.5, 18.53, 3);
insert into dhl_outbound_tariff values (6, 3, 19.67, 3);

insert into dhl_outbound_tariff values (7, 0.5, 13.22, 3);
insert into dhl_outbound_tariff values (7, 1, 16.11, 3);
insert into dhl_outbound_tariff values (7, 1.5, 17.42, 3);
insert into dhl_outbound_tariff values (7, 2, 19.69, 3);
insert into dhl_outbound_tariff values (7, 2.5, 21.15, 3);
insert into dhl_outbound_tariff values (7, 3, 22.52, 3);

insert into dhl_outbound_tariff values (8, 0.5, 14.50, 3);
insert into dhl_outbound_tariff values (8, 1, 18.14, 3);
insert into dhl_outbound_tariff values (8, 1.5, 20.04, 3);
insert into dhl_outbound_tariff values (8, 2, 23.07, 3);
insert into dhl_outbound_tariff values (8, 2.5, 25.18, 3);
insert into dhl_outbound_tariff values (8, 3, 27.10, 3);

insert into dhl_outbound_tariff values (9, 0.5, 16.42, 3);
insert into dhl_outbound_tariff values (9, 1, 20.10, 3);
insert into dhl_outbound_tariff values (9, 1.5, 22.22, 3);
insert into dhl_outbound_tariff values (9, 2, 25.59, 3);
insert into dhl_outbound_tariff values (9, 2.5, 27.94, 3);
insert into dhl_outbound_tariff values (9, 3, 30.10, 3);

COMMIT;
