-- CANDO-734: Cancel Email Template
--            Also create a 'pre_order_email_log' table

BEGIN WORK;

--
-- 'pre_order_email_log' table
--
CREATE TABLE pre_order_email_log (
    id                              SERIAL NOT NULL PRIMARY KEY,
    pre_order_id                    INTEGER NOT NULL REFERENCES pre_order(id),
    correspondence_templates_id     INTEGER NOT NULL REFERENCES correspondence_templates(id),
    operator_id                     INTEGER NOT NULL REFERENCES operator(id),
    date                            TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT current_timestamp
);
ALTER TABLE pre_order_email_log OWNER TO postgres;
GRANT ALL ON TABLE pre_order_email_log TO postgres;
GRANT ALL ON TABLE pre_order_email_log TO www;

GRANT ALL ON SEQUENCE pre_order_email_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_email_log_id_seq TO www;

COMMIT WORK;
