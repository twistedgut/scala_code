-- DCA-45: Set permissions for Putaway Prep tables

BEGIN;

ALTER SEQUENCE putaway_prep_item_id_seq OWNER TO postgres;
GRANT ALL ON SEQUENCE putaway_prep_item_id_seq TO postgres;
GRANT ALL ON SEQUENCE putaway_prep_item_id_seq TO www;

ALTER TABLE putaway_prep_item OWNER TO postgres;
GRANT ALL ON TABLE putaway_prep_item TO postgres;
GRANT ALL ON TABLE putaway_prep_item TO www;

COMMIT;
