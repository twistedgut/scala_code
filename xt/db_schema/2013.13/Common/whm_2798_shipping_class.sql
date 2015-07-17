
-- Shipping Classes for shipping accounts so that we do not have to rely on the name string :/

BEGIN;

CREATE TABLE shipping_class (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);
ALTER TABLE public.shipping_class OWNER TO www;

INSERT INTO shipping_class (name) VALUES
    ('Unknown'),
    ('Domestic'),
    ('International'),
    ('International Road'),
    ('FTBC');

CREATE TABLE shipping_direction (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);
ALTER TABLE public.shipping_direction OWNER TO www;

INSERT INTO shipping_direction (name) VALUES
    ('Outgoing'),
    ('Return');

-- Only used for UPS (DC2) but lets keep the db schemas synced!
CREATE TABLE ups_service (
    id SERIAL PRIMARY KEY,
    code TEXT NOT NULL,
    description TEXT NOT NULL,
    shipping_charge_class_id INTEGER NOT NULL REFERENCES shipping_charge_class (id),
    UNIQUE (code, shipping_charge_class_id)
);
ALTER TABLE public.ups_service OWNER TO www;

CREATE TABLE ups_service_availability (
    id SERIAL PRIMARY KEY,
    ups_service_id INTEGER NOT NULL REFERENCES ups_service (id),
    shipping_class_id INTEGER NOT NULL REFERENCES shipping_class (id),
    shipping_direction_id INTEGER NOT NULL REFERENCES shipping_direction (id),
    shipping_charge_id INTEGER REFERENCES shipping_charge (id), -- NULL implies it is available to those without specific entries
    rank INTEGER NOT NULL,
    UNIQUE (ups_service_id, shipping_class_id, shipping_direction_id, shipping_charge_id)
);
ALTER TABLE public.ups_service_availability OWNER TO www;

ALTER TABLE public.shipping_account ADD COLUMN shipping_class_id INTEGER REFERENCES shipping_class(id);

COMMIT;

