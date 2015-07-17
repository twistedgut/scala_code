/**************************************

Tables required to store processing
time for shipments

Processing time will be stored in minutes

**************************************/

BEGIN;

/****************
* Create Tables
****************/


-- table to store all countries used for shipment
CREATE TABLE sos.country (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

GRANT ALL ON sos.country TO www;
GRANT ALL ON SEQUENCE sos.country_id_seq TO www;


-- table to store regions within above counties
CREATE TABLE sos.region (
    id SERIAL PRIMARY KEY,
    country_id integer NOT NULL references sos.country(id) DEFERRABLE,
    name TEXT NOT NULL
);

GRANT ALL ON sos.region TO www;
GRANT ALL ON SEQUENCE sos.region_id_seq TO www;


-- table to store processing time for
-- class, country, region, attribute
CREATE TABLE sos.processing_time (
    id SERIAL PRIMARY KEY,
    class_id integer references sos.shipment_class(id) DEFERRABLE,
    country_id integer references sos.country(id) DEFERRABLE,
    region_id integer references sos.region(id) DEFERRABLE,
    processing_time numeric NOT NULL,
    class_attribute_id integer references sos.shipment_class_attribute(id) DEFERRABLE
);

GRANT ALL ON sos.processing_time TO www;
GRANT ALL ON SEQUENCE sos.processing_time_id_seq TO www;

COMMIT;
