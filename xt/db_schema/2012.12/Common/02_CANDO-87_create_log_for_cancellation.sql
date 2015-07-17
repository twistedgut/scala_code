-- CANDO-87: Creates a Log table to log the Auto
--           Cancellation of Reservations

BEGIN WORK;

CREATE TABLE reservation_auto_change_log (
    id                  SERIAL NOT NULL PRIMARY KEY,
    reservation_id      INTEGER REFERENCES reservation(id) NOT NULL,
    pre_status_id       INTEGER REFERENCES reservation_status(id) NOT NULL,
    post_status_id      INTEGER REFERENCES reservation_status(id) NOT NULL,
    operator_id         INTEGER REFERENCES operator(id) NOT NULL,
    date                TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE reservation_auto_change_log OWNER TO postgres;
GRANT ALL ON TABLE reservation_auto_change_log TO postgres;
GRANT ALL ON TABLE reservation_auto_change_log TO www;

GRANT ALL ON SEQUENCE reservation_auto_change_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE reservation_auto_change_log_id_seq TO www;

COMMIT WORK;
