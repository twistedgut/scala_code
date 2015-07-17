
BEGIN;

--
-- FLEX-704 - Add tables to keep track of
-- shipping.delivery_date_restriction and
-- delivery_date_restriction_type
--

CREATE TABLE shipping.delivery_date_restriction_type (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255),
    token       VARCHAR(50),
    description VARCHAR(512)
);
ALTER TABLE shipping.delivery_date_restriction_type OWNER TO www;
GRANT ALL ON TABLE shipping.delivery_date_restriction_type TO www;

ALTER TABLE shipping.delivery_date_restriction_type
    ADD CONSTRAINT shipping_delivery_date_restriction_type_token_unique
        UNIQUE (token)
;


INSERT INTO shipping.delivery_date_restriction_type
    ( name                  ,  token                 ,  description ) VALUES
    ('Delivery'             , 'delivery'             , 'The Carrier won''t deliver to the customer on this date'),
    ('Fulfilment or Transit', 'fulfilment_or_transit', 'Neither the Warehouse nor the Carrier will progress the Shipment through Fulfilment or Transit on this date')
;



CREATE TABLE shipping.delivery_date_restriction (
    id                  SERIAL PRIMARY KEY,
    date                DATE NOT NULL,
    shipping_charge_id  INTEGER NOT NULL REFERENCES shipping_charge(id),

    is_restricted       BOOLEAN NOT NULL DEFAULT TRUE,
    restriction_type_id INTEGER NOT NULL REFERENCES shipping.delivery_date_restriction_type(id)
);
ALTER TABLE shipping.delivery_date_restriction OWNER TO www;
GRANT ALL ON TABLE shipping.delivery_date_restriction TO www;

ALTER TABLE shipping.delivery_date_restriction
    ADD CONSTRAINT shipping_delivery_date_restriction_date_shipping_charge_unique
        UNIQUE (date, shipping_charge_id, restriction_type_id)
;



CREATE TABLE shipping.delivery_date_restriction_log (
    id                           SERIAL PRIMARY KEY,
    delivery_date_restriction_id INTEGER NOT NULL REFERENCES shipping.delivery_date_restriction(id),
    datetime                     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    new_is_restricted            BOOLEAN NOT NULL DEFAULT TRUE,
    change_reason                TEXT,
    operator_id                  INTEGER NOT NULL REFERENCES operator(id)
);
ALTER TABLE shipping.delivery_date_restriction_log OWNER TO www;
GRANT ALL ON TABLE shipping.delivery_date_restriction_log TO www;



COMMIT;
