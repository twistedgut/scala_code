--CANDO-2562 : Add 'country_subdivision_group' Table

BEGIN WORK;

--Table:  country_subdivision_groups

CREATE TABLE country_subdivision_group (
    id                          SERIAL PRIMARY KEY,
    name                        CHARACTER VARYING(128) NOT NULL UNIQUE
);

ALTER TABLE country_subdivision_group OWNER TO postgres;
GRANT ALL ON TABLE country_subdivision_group TO postgres;
GRANT ALL ON TABLE country_subdivision_group TO www;

GRANT ALL ON SEQUENCE country_subdivision_group_id_seq TO postgres;
GRANT ALL ON SEQUENCE country_subdivision_group_id_seq TO www;

-- Table: country_subdivision

ALTER table country_subdivision
  ADD COLUMN country_subdivision_group_id INTEGER REFERENCES public.country_subdivision_group(id);

COMMIT WORK;
