-- new schema for website designer navigation management

BEGIN;

-- create designer schema

CREATE SCHEMA designer;
GRANT ALL ON SCHEMA designer TO www;


-- attribute type lookup table
CREATE TABLE designer.attribute_type (
	id serial primary key,
	name varchar(255) not null unique,
	web_attribute varchar(255) not null,
	navigational boolean not null default false
);

-- make sure www can use the table
GRANT ALL ON designer.attribute_type TO www;
GRANT ALL ON designer.attribute_type_id_seq TO www;

-- populate lookup table
INSERT INTO designer.attribute_type VALUES (1, 'Standard Category', 'STD_CAT', true);
INSERT INTO designer.attribute_type VALUES (2, 'Bespoke Category', 'BES_CAT', true);


-- attribute table
CREATE TABLE designer.attribute (
	id serial primary key,
	name varchar(255) not null,
	attribute_type_id integer null references designer.attribute_type(id),
	deleted boolean not null default false,
	synonyms varchar(255) null,
	manual_sort boolean not null default false,
	page_id integer null references web_content.page(id),
	UNIQUE (name, attribute_type_id)
);

-- make sure www can use the table
GRANT ALL ON designer.attribute TO www;
GRANT ALL ON designer.attribute_id_seq TO www;

-- populate attribute table
INSERT INTO designer.attribute (name, attribute_type_id) VALUES ('New-Designers', 1);
INSERT INTO designer.attribute (name, attribute_type_id) VALUES ('Clothes-Designers', 1);
INSERT INTO designer.attribute (name, attribute_type_id) VALUES ('Shoe-Designers', 1);
INSERT INTO designer.attribute (name, attribute_type_id) VALUES ('Bag-Designers', 1);
INSERT INTO designer.attribute (name, attribute_type_id) VALUES ('Accessory-Designers', 1);
INSERT INTO designer.attribute (name, attribute_type_id) VALUES ('Super-Brands', 2);
INSERT INTO designer.attribute (name, attribute_type_id) VALUES ('Hot-Brands', 2);


-- attribute value table
CREATE TABLE designer.attribute_value (
	id serial primary key,
	designer_id integer null references designer(id),
	attribute_id integer null references designer.attribute(id),
	sort_order integer not null default 0,
	deleted boolean not null default false,
	UNIQUE (designer_id, attribute_id)
);

-- make sure www can use the table
GRANT ALL ON designer.attribute_value TO www;
GRANT ALL ON designer.attribute_value_id_seq TO www;


-- attribute type lookup table
CREATE TABLE designer.website_state (
	id serial primary key,
	state varchar(255) not null unique
);

-- make sure www can use the table
GRANT ALL ON designer.website_state TO www;
GRANT ALL ON designer.website_state_id_seq TO www;

-- populate lookup table
INSERT INTO designer.website_state VALUES (1, 'Invisible');
INSERT INTO designer.website_state VALUES (2, 'Visible');
INSERT INTO designer.website_state VALUES (3, 'Coming Soon');

alter table designer add column website_state_id integer references designer.website_state(id) not null default 1;



-- Logging

-- log designer state changes
CREATE TABLE designer.log_website_state (
	id serial primary key,
	designer_id integer not null references designer(id),
	operator_id integer not null references operator(id),
	date timestamp NOT NULL default current_timestamp,
	from_value integer not null references designer.website_state(id),
	to_value integer not null references designer.website_state(id)
);

-- make sure www can use the table
GRANT ALL ON designer.log_website_state TO www;
GRANT ALL ON designer.log_website_state_id_seq TO www;


-- log designer attribute changes
CREATE TABLE designer.log_attribute_value (
	id serial primary key,
	attribute_value_id integer not null references designer.attribute_value(id),
	operator_id integer not null references operator(id),
	date timestamp NOT NULL default current_timestamp,
	action varchar(50) not null
);

-- make sure www can use the table
GRANT ALL ON designer.log_attribute_value TO www;
GRANT ALL ON designer.log_attribute_value_id_seq TO www;

COMMIT;

