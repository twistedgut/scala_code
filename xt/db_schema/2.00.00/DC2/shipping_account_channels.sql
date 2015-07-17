BEGIN;

-- create link table between countries and shipping accounts
-- so we can set different accounts for each sales channel

CREATE TABLE shipping_account__country (
        id serial primary key,
        shipping_account_id integer references shipping_account(id) not null,
        country varchar(100) not null unique,
        channel_id integer references channel(id) not null,
        UNIQUE ( country, channel_id )
);

GRANT ALL ON shipping_account__country TO www;


-- add channel id to shipping charge link tables

ALTER TABLE country_shipping_charge ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
UPDATE country_shipping_charge SET channel_id = 2;
ALTER TABLE country_shipping_charge ALTER COLUMN channel_id SET NOT NULL;

ALTER TABLE state_shipping_charge ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
UPDATE state_shipping_charge SET channel_id = 2;
ALTER TABLE state_shipping_charge ALTER COLUMN channel_id SET NOT NULL;

ALTER TABLE postcode_shipping_charge ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
UPDATE postcode_shipping_charge SET channel_id = 2;
ALTER TABLE postcode_shipping_charge ALTER COLUMN channel_id SET NOT NULL;

-- create new carrier and rename existing DHL carrier
UPDATE carrier SET name = 'DHL Express' WHERE name = 'DHL';
ALTER TABLE carrier ADD COLUMN meter_number varchar(20) NULL;
INSERT INTO carrier VALUES (3, 'DHL Ground', '28420');


-- add channel id to shipping account table
ALTER TABLE shipping_account ADD COLUMN channel_id integer REFERENCES public.channel(id) NULL;
UPDATE shipping_account SET channel_id = 2;
ALTER TABLE shipping_account ALTER COLUMN channel_id SET NOT NULL;


-- fix error when creating manifest status log table, incorrect foreign key constraint
alter table manifest_status_log drop constraint manifest_status_log_status_id_fkey;
alter table manifest_status_log add constraint manifest_status_log_status_id_fkey foreign key (status_id) references manifest_status(id);


-- add carrier to manifest table
ALTER TABLE manifest ADD COLUMN carrier_id integer REFERENCES carrier(id);
UPDATE manifest SET carrier_id = 1;
ALTER TABLE manifest ALTER COLUMN carrier_id SET NOT NULL;


-- create a "run number" lookup as each manifest sent to DHL Ground has to 
-- have a sequential id (can't use manifest id as not all are sent)
CREATE TABLE manifest_run_number (
        run_number integer not null default 1
);

INSERT INTO manifest_run_number VALUES (1);

GRANT ALL ON manifest_run_number TO www;


-- create LP sequence for DHL Ground
CREATE SEQUENCE dhl_ground_licence_plate_nr MINVALUE 28420000001 MAXVALUE 28420999999 START 28420000001;
GRANT ALL ON dhl_ground_licence_plate_nr TO www;

COMMIT;