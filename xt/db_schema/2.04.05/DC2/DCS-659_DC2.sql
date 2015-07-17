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

-- UPS
INSERT INTO returns_charge (channel_id, carrier_id, country_id, currency_id, charge) (
    SELECT 4, 2, id, 2, 7.95 FROM country
);


COMMIT;