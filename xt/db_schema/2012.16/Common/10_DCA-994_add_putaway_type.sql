
--
-- DCA-944 - Add column to store stock_process.putaway_type
--           Also add value table for the constants
--

BEGIN;


CREATE TABLE putaway_type (
    id          SERIAL NOT NULL PRIMARY KEY,
    name        CHARACTER VARYING(255) NOT NULL,
    UNIQUE(name)
);
ALTER TABLE putaway_type OWNER TO postgres;
GRANT ALL ON TABLE putaway_type TO postgres;
GRANT ALL ON TABLE putaway_type TO www;

GRANT ALL ON SEQUENCE putaway_type_id_seq TO postgres;
GRANT ALL ON SEQUENCE putaway_type_id_seq TO www;

INSERT INTO putaway_type (name) VALUES
    ('Goods In'),
    ('Stock Transfer'),
    ('Returns'),
    ('Sample'),
    ('Processed Quarantine')
;



ALTER TABLE stock_process
    ADD COLUMN putaway_type_id INTEGER NULL
        REFERENCES putaway_type(id);


COMMIT;
