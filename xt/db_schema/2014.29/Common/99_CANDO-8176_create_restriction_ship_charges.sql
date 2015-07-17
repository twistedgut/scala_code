-- CANDO-8176: Create 'ship_restriction_allowed_shipping_charge' table to create
--             a link betweek Shipping Charges and Ship Restrictions

BEGIN WORK;

CREATE TABLE ship_restriction_allowed_shipping_charge (
    id                      SERIAL PRIMARY KEY,
    ship_restriction_id     INTEGER REFERENCES ship_restriction(id) NOT NULL,
    shipping_charge_id      INTEGER REFERENCES shipping_charge(id) NOT NULL,
    UNIQUE( ship_restriction_id, shipping_charge_id )
);

ALTER TABLE ship_restriction_allowed_shipping_charge OWNER TO postgres;
GRANT ALL ON TABLE ship_restriction_allowed_shipping_charge TO postgres;
GRANT ALL ON TABLE ship_restriction_allowed_shipping_charge TO www;

GRANT ALL ON SEQUENCE ship_restriction_allowed_shipping_charge_id_seq TO postgres;
GRANT ALL ON SEQUENCE ship_restriction_allowed_shipping_charge_id_seq TO www;

COMMIT WORK;
