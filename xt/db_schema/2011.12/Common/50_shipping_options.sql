BEGIN;

CREATE SCHEMA shipping;
ALTER SCHEMA shipping OWNER TO www;

CREATE TABLE shipping.carrier (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    meter_number VARCHAR(100) DEFAULT NULL,
    tracking_uri VARCHAR(255) DEFAULT '',
    UNIQUE(name)
);
ALTER TABLE shipping.carrier OWNER TO www;


CREATE TABLE shipping.option (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(255) NOT NULL,
    description VARCHAR(255) NOT NULL,

    carrier_id INTEGER REFERENCES shipping.carrier(id) DEFERRABLE NOT NULL,
    UNIQUE(name)
);
ALTER TABLE shipping.option OWNER TO www;


CREATE TABLE shipping.account_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    UNIQUE(name)
);
ALTER TABLE shipping.account_type OWNER TO www;


CREATE TABLE shipping.account (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    return_cutoff_days INTEGER,

    option_id INTEGER REFERENCES shipping.option(id) DEFERRABLE NOT NULL,
    account_type_id INTEGER REFERENCES shipping.account_type(id)
        DEFERRABLE NOT NULL

-- taken out because there are duplicate names :/
--    UNIQUE(name)
);
ALTER TABLE shipping.account OWNER TO www;


CREATE TABLE shipping.location (
    id SERIAL PRIMARY KEY,
    country_id INTEGER REFERENCES public.country(id) DEFERRABLE NOT NULL,
    postcode VARCHAR(20),
    UNIQUE(country_id,postcode)
);
ALTER TABLE shipping.location OWNER TO www;


CREATE TABLE shipping.zone (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);
ALTER TABLE shipping.zone OWNER TO www;


CREATE TABLE shipping.zone_location (
    id SERIAL PRIMARY KEY,
    zone_id INTEGER REFERENCES
        shipping.zone(id) DEFERRABLE NOT NULL,
    location_id INTEGER REFERENCES
        shipping.location(id) DEFERRABLE NOT NULL,
    UNIQUE(zone_id,location_id)
);
ALTER TABLE shipping.zone_location OWNER TO www;


CREATE TABLE shipping.option_zone (
    id SERIAL PRIMARY KEY,
    option_id INTEGER REFERENCES shipping.option(id) DEFERRABLE,
    zone_id INTEGER REFERENCES shipping.zone(id) DEFERRABLE,
    UNIQUE(option_id,zone_id)
);
ALTER TABLE shipping.option_zone OWNER TO www;


CREATE TABLE shipping.charge_class (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255)
);
ALTER TABLE shipping.charge_class OWNER TO www;

CREATE TABLE shipping.charge (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) NOT NULL,
    description VARCHAR(255),
    charge NUMERIC(10,2) NOT NULL,
    currency_id INTEGER REFERENCES
        public.currency(id) DEFERRABLE NOT NULL,
    charge_class_id INTEGER REFERENCES
        shipping.charge_class(id) DEFERRABLE NOT NULL,
    flat_rate BOOLEAN DEFAULT FALSE NOT NULL,

    
    channel_id INTEGER REFERENCES
        public.channel(id) DEFERRABLE,
-- FIXME: taken out so we can migrate
--        public.channel(id) DEFERRABLE NOT NULL,
    account_id INTEGER REFERENCES
        shipping.account(id) DEFERRABLE
-- FIXME: taken out so we can migrate
--        shipping.account(id) DEFERRABLE NOT NULL,

-- FIXME: taken out so we can migrate
--    UNIQUE(sku,account_id,channel_id)
);
ALTER TABLE shipping.charge OWNER TO www;

--ALTER TABLE public.shipment
--    ADD COLUMN charge_id INTEGER REFERENCES
--        shipping.charge(id) DEFERRABLE;


COMMIT;
