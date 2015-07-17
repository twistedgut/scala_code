--CANDO-8229: LQ-Hazmat product restriction

BEGIN WORK;

-- create table of restricted PostCode list for LQ-Hazmat products

CREATE TABLE ship_restriction_exclude_postcode (
    id serial primary key,
    ship_restriction_id integer references ship_restriction(id) NOT NULL,
    postcode varchar(20) NOT NULL,
    country_id INTEGER references country(id) NOT NULL,
    UNIQUE(ship_restriction_id, postcode, country_id)
);
ALTER TABLE ship_restriction_exclude_postcode OWNER TO postgres;
GRANT ALL ON TABLE ship_restriction_exclude_postcode TO postgres;
GRANT ALL ON TABLE ship_restriction_exclude_postcode TO www;

GRANT ALL ON SEQUENCE ship_restriction_exclude_postcode_id_seq TO postgres;
GRANT ALL ON SEQUENCE ship_restriction_exclude_postcode_id_seq TO www;


COMMIT WORK;
