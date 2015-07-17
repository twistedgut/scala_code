-- CANDO-80: New 'return_email_log' table

BEGIN WORK;

--
-- 'return_email_log' table
--
CREATE TABLE return_email_log (
    id                              SERIAL NOT NULL PRIMARY KEY,
    return_id                       INTEGER NOT NULL REFERENCES return(id),
    correspondence_templates_id     INTEGER NOT NULL REFERENCES correspondence_templates(id),
    operator_id                     INTEGER NOT NULL REFERENCES operator(id),
    date                            TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT current_timestamp
);
ALTER TABLE return_email_log OWNER TO postgres;
GRANT ALL ON TABLE return_email_log TO postgres;
GRANT ALL ON TABLE return_email_log TO www;

GRANT ALL ON SEQUENCE return_email_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE return_email_log_id_seq TO www;

COMMIT WORK;
