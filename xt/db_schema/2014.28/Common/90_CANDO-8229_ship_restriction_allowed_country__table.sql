--CANDO-8229: LQ-Hazmat product restriction

BEGIN WORK;

-- create table of allowed Countries for LQ-Hazmat products

CREATE TABLE ship_restriction_allowed_country (
    id serial primary key,
    ship_restriction_id INTEGER references ship_restriction(id) NOT NULL,
    country_id INTEGER references country(id) NOT NULL,
    UNIQUE(ship_restriction_id, country_id)
);
ALTER TABLE ship_restriction_allowed_country OWNER TO postgres;
GRANT ALL ON TABLE ship_restriction_allowed_country TO postgres;
GRANT ALL ON TABLE ship_restriction_allowed_country TO www;

GRANT ALL ON SEQUENCE ship_restriction_allowed_country_id_seq TO postgres;
GRANT ALL ON SEQUENCE ship_restriction_allowed_country_id_seq TO www;


COMMIT WORK;
