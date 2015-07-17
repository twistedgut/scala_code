BEGIN;

CREATE TABLE ship_restriction (
    id serial primary key,
    title varchar(100) NOT NULL,
    code varchar(10) NOT NULL UNIQUE
);

GRANT ALL ON ship_restriction TO www;
GRANT ALL ON ship_restriction_id_seq TO www;

INSERT INTO ship_restriction (title, code) VALUES ('Chinese Origin', 'CH_ORIGIN');
INSERT INTO ship_restriction (title, code) VALUES ('CITES', 'CITES');
INSERT INTO ship_restriction (title, code) VALUES ('Fish & Wildlife', 'FISH_WILD');
INSERT INTO ship_restriction (title, code) VALUES ('Fine Jewelry', 'FINE_JEWEL');


CREATE TABLE ship_restriction_location (
    id serial primary key,
    ship_restriction_id integer references manifest_status(id) NOT NULL,
    location varchar(10) NOT NULL,
    type varchar(10) NOT NULL,
    UNIQUE(ship_restriction_id, location, type)
);

GRANT ALL ON ship_restriction_location TO www;
GRANT ALL ON ship_restriction_location_id_seq TO www;

-- Chinese origin locations
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Chinese Origin'), 'TR', 'COUNTRY');
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Chinese Origin'), 'MX', 'COUNTRY');
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) (
    SELECT (SELECT id FROM ship_restriction WHERE title = 'Chinese Origin'), code, 'COUNTRY' FROM country WHERE code != '' AND sub_region_id = (SELECT id FROM sub_region WHERE sub_region = 'EU Member States')
);

-- CITES locations
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'CITES'), 'CA', 'STATE');
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) (
    SELECT (SELECT id FROM ship_restriction WHERE title = 'CITES'), code, 'COUNTRY' FROM country WHERE code != '' AND country != 'United States'
);

-- Fish & Wildlife
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fish & Wildlife'), 'CA', 'STATE');
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) (
    SELECT (SELECT id FROM ship_restriction WHERE title = 'Fish & Wildlife'), code, 'COUNTRY' FROM country WHERE country != 'United States' AND code != ''
);

CREATE TABLE link_product__ship_restriction (
    id serial primary key,
    product_id integer references product(id) NOT NULL,    
    ship_restriction_id integer references manifest_status(id) NOT NULL,
    UNIQUE(product_id, ship_restriction_id)
);

GRANT ALL ON link_product__ship_restriction TO www;
GRANT ALL ON link_product__ship_restriction_id_seq TO www;

-- Chinese origin products
INSERT INTO link_product__ship_restriction (product_id, ship_restriction_id) (
    SELECT product_id, (SELECT id FROM ship_restriction WHERE title = 'Chinese Origin') FROM shipping_attribute WHERE country_id = (SELECT id FROM country WHERE country = 'China')
);

-- CITES products
INSERT INTO link_product__ship_restriction (product_id, ship_restriction_id) (
    SELECT product_id, (SELECT id FROM ship_restriction WHERE title = 'CITES') FROM shipping_attribute WHERE cites_restricted IS TRUE
);

-- Fish & Wildlife products
INSERT INTO link_product__ship_restriction (product_id, ship_restriction_id) (
    SELECT product_id, (SELECT id FROM ship_restriction WHERE title = 'Fish & Wildlife') FROM shipping_attribute WHERE fish_wildlife IS TRUE
);

-- Fine Jewelry products
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Argentina'), 'COUNTRY');       
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Dominican Republic'), 'COUNTRY');      
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Egypt'), 'COUNTRY');   
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Georgia'), 'COUNTRY');         
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Greenland'), 'COUNTRY');       
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Iceland'), 'COUNTRY');         
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Indonesia'), 'COUNTRY');       
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Japan'), 'COUNTRY');   
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Jordan'), 'COUNTRY');  
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Kazakhstan'), 'COUNTRY');      
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Macau'), 'COUNTRY');   
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Oman'), 'COUNTRY');    
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Switzerland'), 'COUNTRY');    
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Turkey'), 'COUNTRY');
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Venezuela'), 'COUNTRY');      
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Vietnam'), 'COUNTRY');         
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Fine Jewelry'), (SELECT code FROM country WHERE country = 'Yemen'), 'COUNTRY');

COMMIT;