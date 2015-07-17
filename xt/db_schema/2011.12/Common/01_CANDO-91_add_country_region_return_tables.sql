-- CANDO-91: Will create two new tables 'return_country_refund_charge' & 'return_sub_region_refund_charge'
--           these will contain the Countries & Sub-Regions and whether they can have Tax & Duties refunded or whether their
--           Tax & Duties can be charged again for an Exchange.

BEGIN WORK;

--
-- CREATE refund_charge_type - This table will hold the different Types that can be Charged or Refunded: Tax, Duty.
--
CREATE TABLE refund_charge_type (
    id      SERIAL PRIMARY KEY,
    type    CHARACTER VARYING(20) NOT NULL
);
CREATE UNIQUE INDEX idx_refund_charge_type__type ON refund_charge_type(type);

ALTER TABLE refund_charge_type OWNER TO postgres;
GRANT ALL ON TABLE refund_charge_type TO postgres;
GRANT ALL ON TABLE refund_charge_type TO www;

GRANT ALL ON SEQUENCE refund_charge_type_id_seq TO postgres;
GRANT ALL ON SEQUENCE refund_charge_type_id_seq TO www;

-- Populate refund_charge_type table
INSERT INTO refund_charge_type (type) VALUES('Tax');
INSERT INTO refund_charge_type (type) VALUES('Duty');


--
-- CREATE return_country_refund_charge
--
CREATE TABLE return_country_refund_charge (
    id                      SERIAL PRIMARY KEY,
    country_id              INTEGER REFERENCES country(id) NOT NULL,
    refund_charge_type_id   INTEGER REFERENCES refund_charge_type(id) NOT NULL,
    can_refund_for_return   BOOLEAN DEFAULT FALSE NOT NULL,
    no_charge_for_exchange  BOOLEAN DEFAULT FALSE NOT NULL
);
CREATE UNIQUE INDEX idx_return_country_refund_charge__country_id_type_id ON return_country_refund_charge(country_id,refund_charge_type_id);

ALTER TABLE return_country_refund_charge OWNER TO postgres;
GRANT ALL ON TABLE return_country_refund_charge TO postgres;
GRANT ALL ON TABLE return_country_refund_charge TO www;

GRANT ALL ON SEQUENCE return_country_refund_charge_id_seq TO postgres;
GRANT ALL ON SEQUENCE return_country_refund_charge_id_seq TO www;


--
-- CREATE return_sub_region_refund_charge
--
CREATE TABLE return_sub_region_refund_charge (
    id                      SERIAL PRIMARY KEY,
    sub_region_id           INTEGER REFERENCES sub_region(id) NOT NULL,
    refund_charge_type_id   INTEGER REFERENCES refund_charge_type(id) NOT NULL,
    can_refund_for_return   BOOLEAN DEFAULT FALSE NOT NULL,
    no_charge_for_exchange  BOOLEAN DEFAULT FALSE NOT NULL
);
CREATE UNIQUE INDEX idx_return_sub_region_refund_charge__sub_region_id_type_id ON return_sub_region_refund_charge(sub_region_id,refund_charge_type_id);

ALTER TABLE return_sub_region_refund_charge OWNER TO postgres;
GRANT ALL ON TABLE return_sub_region_refund_charge TO postgres;
GRANT ALL ON TABLE return_sub_region_refund_charge TO www;

GRANT ALL ON SEQUENCE return_sub_region_refund_charge_id_seq TO postgres;
GRANT ALL ON SEQUENCE return_sub_region_refund_charge_id_seq TO www;

COMMIT WORK;
