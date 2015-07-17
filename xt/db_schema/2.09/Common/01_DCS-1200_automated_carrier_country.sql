-- Create table 'automated_carrier_country' to hold carriers and countries that can be automated
-- or have real time carrier booking.

BEGIN WORK;

CREATE TABLE automated_carrier_country (
    carrier_id INTEGER REFERENCES carrier(id) NOT NULL,
    country_id INTEGER REFERENCES country(id) NOT NULL,
    CONSTRAINT automated_carrier_country_pkey PRIMARY KEY (carrier_id,country_id)
);
ALTER TABLE automated_carrier_country OWNER TO postgres;
GRANT ALL ON TABLE automated_carrier_country TO postgres;
GRANT ALL ON TABLE automated_carrier_country TO www;

COMMIT WORK;
