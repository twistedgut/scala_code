
-- CANDO-7918: New 'correspondence_templates_log' table

BEGIN WORK;

--
-- 'correspondence_templates_log' table
--
CREATE TABLE correspondence_templates_log (
    id                              SERIAL NOT NULL PRIMARY KEY,
    correspondence_templates_id     INTEGER NOT NULL REFERENCES correspondence_templates(id),
    operator_id                     INTEGER NOT NULL REFERENCES operator(id),
    last_modified                   TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE correspondence_templates_log OWNER TO postgres;
GRANT ALL ON TABLE correspondence_templates_log TO postgres;
GRANT ALL ON TABLE correspondence_templates_log TO www;

GRANT ALL ON SEQUENCE correspondence_templates_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE correspondence_templates_log_id_seq TO www;

COMMIT WORK;

