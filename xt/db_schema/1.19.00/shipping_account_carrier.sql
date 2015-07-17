-- functionality to handle multiple carriers for DC2 (DHL, UPS etc...)

BEGIN;

-- new lookup table to store carrier
CREATE TABLE carrier (
	id serial primary key,
	name varchar(255) not null
);

GRANT ALL ON carrier TO www;

INSERT INTO carrier (name) VALUES ('DHL');
INSERT INTO carrier (name) VALUES ('UPS');

-- add carrier to shipping accounts
ALTER TABLE shipping_account ADD COLUMN carrier_id INTEGER REFERENCES carrier(id);

-- back fill existing entries as DHL
UPDATE shipping_account SET carrier_id = (SELECT id FROM carrier WHERE name = 'DHL') WHERE name in ('Domestic', 'International', 'FTBC');

-- create new entry for UPS Domestic
INSERT INTO shipping_account (id, name, account_number, carrier_id) VALUES ((select max(id) + 1 from shipping_account), 'Domestic', '', (SELECT id FROM carrier WHERE name = 'UPS'));

-- create link table between postcodes and shipping account
CREATE TABLE shipping_account__postcode (
	id serial primary key,
	shipping_account_id integer references shipping_account(id) not null,
	postcode varchar(100) not null unique
);

GRANT ALL ON shipping_account__postcode TO www;


-- take 'DHL' out of shipping charge class names
UPDATE shipping_charge_class SET class = 'Ground' WHERE class = 'DHL Ground';
UPDATE shipping_charge_class SET class = 'Air' WHERE class = 'DHL Air';


-- copy shipping_account__postcode (shipping_account_id, postcode) from '/tmp/ups_zipcodes.txt';

COMMIT;

