-- Add a local exchange rate table and
-- add a local currency code to country table

BEGIN;

-- Create local exchange rate table
CREATE TABLE local_exchange_rate (
    id serial PRIMARY KEY,
    country_id integer REFERENCES country(id) NOT NULL,
    rate numeric(12, 3) NOT NULL,
    start_date timestamp NOT NULL DEFAULT current_timestamp(0),
    end_date timestamp
);

GRANT ALL ON local_exchange_rate TO www;
GRANT ALL ON local_exchange_rate_id_seq TO www;

-- Add local currency code column
ALTER TABLE country ADD COLUMN local_currency_code varchar(5);

COMMIT;
