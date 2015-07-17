BEGIN;

CREATE TABLE returns_charge (
    id serial primary key,
    channel_id integer references channel(id) NOT NULL,
    carrier_id integer references carrier(id) NOT NULL,
    country_id integer references country(id) NOT NULL,
    currency_id integer references currency(id) NOT NULL,
    charge numeric(10,2) NOT NULL DEFAULT 0,
    UNIQUE(channel_id, carrier_id, country_id, currency_id)
);

GRANT ALL ON returns_charge TO www;
GRANT ALL ON returns_charge_id_seq TO www;


-- DHL Express Domestic
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) VALUES (3, 1, (SELECT id FROM country WHERE country = 'United Kingdom'), 1, 8.00 );
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) VALUES (3, 1, (SELECT id FROM country WHERE country = 'United Kingdom'), 3, 9.44 );

-- DHL Express Europe
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) (
    SELECT 3, 1, id, 1, 16.00 FROM country WHERE country != 'United Kingdom' AND sub_region_id IN (select id from sub_region where region_id = (select id from region where region = 'Europe'))
);
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) (
    SELECT 3, 1, id, 3, 18.88 FROM country WHERE country != 'United Kingdom' AND sub_region_id IN (select id from sub_region where region_id = (select id from region where region = 'Europe'))
);

-- DHL Express Americas
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) (
    SELECT 3, 1, id, 1, 40.00 FROM country WHERE country != 'United Kingdom' AND sub_region_id IN (select id from sub_region where region_id = (select id from region where region = 'Americas'))
);
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) (
    SELECT 3, 1, id, 3, 47.20 FROM country WHERE country != 'United Kingdom' AND sub_region_id IN (select id from sub_region where region_id = (select id from region where region = 'Americas'))
);


-- DHL Express ROW
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) (
    SELECT 3, 1, id, 1, 25.00 FROM country WHERE country != 'United Kingdom' AND sub_region_id IN (select id from sub_region where region_id in (select id from region where region not in ('Europe', 'Americas')))
);
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) (
    SELECT 3, 1, id, 3, 29.50 FROM country WHERE country != 'United Kingdom' AND sub_region_id IN (select id from sub_region where region_id in (select id from region where region not in ('Europe', 'Americas')))
);


-- DHL Ground
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) (
    SELECT 3, 3, id, 1, 16.00 FROM country
);
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) (
    SELECT 3, 3, id, 3, 18.88 FROM country
);


COMMIT;