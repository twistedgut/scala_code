
-- DCA-956: Induction - create a Physical Place, link Container to it

BEGIN;

CREATE TABLE physical_place (
    id          INTEGER PRIMARY KEY,
    name        TEXT UNIQUE NOT NULL,
    description TEXT NOT NULL,

    created     TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
COMMENT ON TABLE physical_place IS
'A physical place (as opposed to a logical place, like the Commissioner) in which e.g. a Container may be located in.';

ALTER TABLE physical_place OWNER TO postgres;
GRANT ALL ON TABLE physical_place TO postgres;
GRANT ALL ON TABLE physical_place TO www;



INSERT INTO physical_place (id, name, description)
VALUES (
    1,
    'Cage',
    'Room in the warehouse where high-value products are stored until picking'
);



ALTER TABLE container
    ADD COLUMN physical_place_id INTEGER NULL
        REFERENCES physical_place (id);

COMMENT ON COLUMN container.physical_place_id IS
'For when the Container is in a known physcial place, e.g. the Cage';



COMMIT;

