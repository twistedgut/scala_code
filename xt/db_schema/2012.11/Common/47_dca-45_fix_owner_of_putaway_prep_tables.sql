-- DCA-45: Set permissions for Putaway Prep tables

BEGIN;

ALTER TABLE putaway_prep_status_id_seq OWNER TO postgres;
GRANT ALL ON TABLE putaway_prep_status_id_seq TO postgres;
GRANT ALL ON TABLE putaway_prep_status_id_seq TO www;

ALTER TABLE putaway_prep_status OWNER TO postgres;
GRANT ALL ON TABLE putaway_prep_status TO postgres;
GRANT ALL ON TABLE putaway_prep_status TO www;

ALTER TABLE putaway_prep_id_seq OWNER TO postgres;
GRANT ALL ON TABLE putaway_prep_id_seq TO postgres;
GRANT ALL ON TABLE putaway_prep_id_seq TO www;

ALTER TABLE putaway_prep OWNER TO postgres;
GRANT ALL ON TABLE putaway_prep TO postgres;
GRANT ALL ON TABLE putaway_prep TO www;

COMMIT;
