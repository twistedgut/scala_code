-- PS-1004 Create shipping.descritpion table
-- This was going to be shipping.attritube but shipping_attribute already exists
-- This is a step toward XT being the authority on shipping data
-- Most of these attritubtes are for display purposes in the purchase path
-- See the JIRA ticket for more information

BEGIN;

CREATE TABLE shipping.country_charge (
    id SERIAL,
    shipping_charge_id INTEGER REFERENCES shipping_charge(id),
    country_id INTEGER REFERENCES country(id),
    currency_id INTEGER REFERENCES currency(id),
    charge NUMERIC(10,2),
    UNIQUE (shipping_charge_id, country_id, currency_id)
);
ALTER TABLE shipping.country_charge OWNER TO www;

GRANT ALL ON shipping.country_charge TO www;
GRANT ALL ON shipping.country_charge TO postgres;

CREATE TABLE shipping.region_charge (
    id SERIAL PRIMARY KEY,
    shipping_charge_id INTEGER REFERENCES shipping_charge(id),
    region_id INTEGER REFERENCES region(id),
    currency_id INTEGER REFERENCES currency(id),
    charge NUMERIC(10,2),
    UNIQUE (shipping_charge_id, region_id, currency_id)
);
ALTER TABLE shipping.region_charge OWNER TO www;

GRANT ALL ON shipping.region_charge TO www;
GRANT ALL ON shipping.region_charge TO postgres;

CREATE TABLE shipping.description (
    name TEXT NOT NULL,
    public_name TEXT NOT NULL,
    title TEXT NOT NULL,
    public_title TEXT NOT NULL,
    short_delivery_description TEXT,
    long_delivery_description TEXT,
    estimated_delivery TEXT,
    delivery_confirmation TEXT,
    shipping_charge_id INTEGER REFERENCES shipping_charge(id) DEFERRABLE PRIMARY KEY
);
ALTER TABLE shipping.description OWNER TO www;

GRANT ALL ON shipping.description TO www;
GRANT ALL ON shipping.description TO postgres;

COMMIT;
