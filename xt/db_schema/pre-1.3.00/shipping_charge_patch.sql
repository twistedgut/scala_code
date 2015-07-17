-- Purpose:
--  Create/Amend tables for US Shipping changes

BEGIN;

create table shipping_charge_class (
	id serial primary key,
	class varchar(255) NOT NULL
	);

grant all on shipping_charge_class to www;
grant all on shipping_charge_class_id_seq to www;

insert into shipping_charge_class values (1, 'Same Day');
insert into shipping_charge_class values (2, 'DHL Ground');
insert into shipping_charge_class values (3, 'DHL Air');


create table shipping_charge (
	id serial primary key,
	sku varchar(20) NOT NULL,
	description varchar(255) NOT NULL,
	charge numeric(10,2) NOT NULL,
	currency_id integer references currency(id) NOT NULL,
	flat_rate boolean NOT NULL default false,
	class_id integer references shipping_charge_class(id) NOT NULL
	);

grant all on shipping_charge to www;
grant all on shipping_charge_id_seq to www;


insert into shipping_charge values (0, '', 'Unknown', 0, 0, true, 3);
insert into shipping_charge values (1, '900000-001', 'International', 30.00, 1, false, 3);
insert into shipping_charge values (2, '900001-001', 'Premier - Zone 3', 16.60, 1, true, 1);
insert into shipping_charge values (3, '900002-001', 'Premier - Zone 2', 12.34, 1, true, 1);
insert into shipping_charge values (4, '900003-001', 'UK Express', 8.51, 1, true, 3);
insert into shipping_charge values (5, '900004-001', 'North America', 30.00, 1, false, 3);
insert into shipping_charge values (6, '900005-001', 'Premier - Zone 1', 9.79, 1, true, 1);
insert into shipping_charge values (7, '900008-001', 'Mainland Europe', 20.00, 1, false, 3);
insert into shipping_charge values (8, '9000119-001', 'Pre-Order, UK', 8.51, 1, true, 3);
insert into shipping_charge values (9, '9000120-001', 'Pre-Order, Europe', 20.00, 1, false, 3);
insert into shipping_charge values (10, '9000121-001', 'Pre-Order, North America', 30.00, 1, false, 3);
insert into shipping_charge values (11, '9000122-001', 'Pre-Order, Channel Island', 8.51, 1, true, 3);
insert into shipping_charge values (12, '9000123-001', 'Pre-Order, International', 30.00, 1, false, 3);

create table country_shipping_charge (
	id serial primary key,
	country_id integer references country(id) NOT NULL,
	shipping_charge_id integer references shipping_charge(id) NOT NULL
	);

grant all on country_shipping_charge to www;
grant all on country_shipping_charge_id_seq to www;


create table state_shipping_charge (
	id serial primary key,
	state varchar(255) NOT NULL,
	country_id integer references country(id) NOT NULL,
	shipping_charge_id integer references shipping_charge(id) NOT NULL
	);

grant all on state_shipping_charge to www;
grant all on state_shipping_charge_id_seq to www;


create table postcode_shipping_charge (
	id serial primary key,
	postcode varchar(255) NOT NULL,
	country_id integer references country(id) NOT NULL,
	shipping_charge_id integer references shipping_charge(id) NOT NULL
	);

grant all on postcode_shipping_charge to www;
grant all on postcode_shipping_charge_id_seq to www;


-- postcode shipping charges

-- Premier Zone 1

insert into postcode_shipping_charge values (default, 'E14', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'EC1', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'EC2', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'EC3', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'EC4', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'N1', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'NW1', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'NW3', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'NW8', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'W1', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'W2', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'W6', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'W8', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'W9', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'W10', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'W11', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'W12', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'SW1', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'SW3', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'SW5', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'SW6', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'SW7', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'SW10', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'SE1', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'WC1', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'WC2', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'E1', (select id from country where country = 'United Kingdom'), 6);
insert into postcode_shipping_charge values (default, 'W14', (select id from country where country = 'United Kingdom'), 6);

-- Premier Zone 2

insert into postcode_shipping_charge values (default, 'E2', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'E8', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'N5', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'N7', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'N16', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'NW2', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'NW6', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'NW10', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'W3', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'W4', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'SW8', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'SW11', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'SW13', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'SE11', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'SE16', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'SE17', (select id from country where country = 'United Kingdom'), 3);
insert into postcode_shipping_charge values (default, 'NW5', (select id from country where country = 'United Kingdom'), 3);

-- Premier Zone 3

insert into postcode_shipping_charge values (default, 'E3', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E4', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E5', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E6', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E7', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E9', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E10', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E11', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E12', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E13', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E15', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E16', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E17', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'E18', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N2', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N3', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N4', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N6', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N8', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N9', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N10', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N11', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N12', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N13', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N14', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N15', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N17', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N18', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N19', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N20', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N21', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'N22', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'NW4', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'NW7', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'NW9', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'NW11', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'W5', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'W7', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'TW9', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW2', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW4', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW9', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW12', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW14', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW15', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW16', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW17', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW18', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW19', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SW20', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE2', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE3', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE4', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE5', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE6', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE7', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE8', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE9', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE10', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE12', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE13', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE14', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE15', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE18', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE19', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE20', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE21', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE22', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE23', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE24', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE25', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE26', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE27', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'SE28', (select id from country where country = 'United Kingdom'), 2);
insert into postcode_shipping_charge values (default, 'W13', (select id from country where country = 'United Kingdom'), 2);



-- state shipping charges



-- country shipping charges

-- UK Express

insert into country_shipping_charge values (default, (select id from country where country = 'United Kingdom'), 4);
insert into country_shipping_charge values (default, (select id from country where country = 'Jersey'), 4);
insert into country_shipping_charge values (default, (select id from country where country = 'Guernsey'), 4);

-- Mainland Europe

insert into country_shipping_charge values (default, (select id from country where country = 'Malta'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Monaco'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Netherlands'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Norway'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Poland'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Portugal'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Slovakia'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Slovenia'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Spain'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Sweden'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Switzerland'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Austria'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Albania'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Andorra'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Belgium'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Canary Islands'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Cyprus'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Czech Republic'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Denmark'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Estonia'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Faroe Islands'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Finland'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'France'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Germany'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Greece'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Hungary'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Ireland'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Italy'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Latvia'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Lithuania'), 7);
insert into country_shipping_charge values (default, (select id from country where country = 'Luxembourg'), 7);


-- North America

insert into country_shipping_charge values (default, (select id from country where country = 'Martinique'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Montserrat'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Nicaragua'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Panama'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Paraguay'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Saint Kitts and Nevis'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Saint Lucia'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Saint Vincent and the Grenadines'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Suriname'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Trinidad & Tobago'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Turks & Caicos Islands'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'United States'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Anguilla'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Belize'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Bolivia'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Netherlands Antilles'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Canada'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Dominica'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Colombia'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Ecuador'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'El Salvador'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Falkland Islands'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'French Guiana'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Grenada'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Aruba'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Guatemala'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Honduras'), 5);
insert into country_shipping_charge values (default, (select id from country where country = 'Jamaica'), 5);


-- International

insert into country_shipping_charge values (default, (select id from country where country = 'Malawi'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Argentina'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Maldives'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Mauritius'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Mexico'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Moldova'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Mongolia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Morocco'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Mozambique'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Serbia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Namibia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Nepal'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'New Caledonia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'New Zealand'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Oman'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Papua New Guinea'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Peru'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Brunei'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Puerto Rico'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Qatar'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Romania'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Brazil'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Saipan'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Samoa'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Sao Tome & Principe'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Saudi Arabia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Seychelles'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Sierra Leone'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Singapore'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Chile'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Sri Lanka'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'St Barthelemy'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Swaziland'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Taiwan ROC'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Tanzania'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'China'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Togo'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Tonga'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Egypt'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Tuvalu'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Ukraine'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'United Arab Emirates'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Vanuatu'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Jordan'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Vietnam'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'British Virgin Islands'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'US Virgin Islands'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Yemen'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Australia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Azerbaijan'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Bahamas'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Bahrain'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Bangladesh'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Barbados'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Malaysia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'French Polynesia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Algeria'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Antigua and Barbuda'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Belarus'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Bermuda'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Bhutan'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Montenegro'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Bosnia-Herzegovina'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Botswana'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Philippines'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Russia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Bulgaria'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Cambodia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Cape Verde Islands'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Cayman Islands'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'South Africa'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'South Korea'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Comoros Islands'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Cook Islands'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Costa Rica'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Croatia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Dominican Republic'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'East Timor'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Thailand'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Fiji'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Gabon'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Gambia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Georgia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Ghana'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Gibraltar'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Greenland'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Turkey'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Guadeloupe'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Guam'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Guyana'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Hong Kong'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Iceland'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'India'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Indonesia'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Israel'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Japan'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Venezuela'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Kazakhstan'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Kenya'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Kuwait'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Laos'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Lebanon'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Lesotho'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Liechtenstein'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Macau'), 1);
insert into country_shipping_charge values (default, (select id from country where country = 'Macedonia'), 1);


alter table shipment add column shipping_charge_id integer references shipping_charge(id) NOT NULL default 0;

COMMIT;
