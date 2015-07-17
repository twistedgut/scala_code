-- CANDO-105: Create table 'reservation_operator_log'

BEGIN WORK;

-- Create table
CREATE TABLE reservation_operator_log (
    id                      SERIAL NOT NULL,
    created_timestamp       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    reservation_id          INTEGER NOT NULL,
    operator_id             INTEGER NOT NULL,
    from_operator_id        INTEGER NOT NULL,
    to_operator_id          INTEGER NOT NULL,
    reservation_status_id   INTEGER NOT NULL,
    --
    CONSTRAINT reservation_operator_log_pkey
        PRIMARY KEY (id),
    CONSTRAINT reservation_id_fkey
        FOREIGN KEY (reservation_id) REFERENCES reservation (id),
    CONSTRAINT operator_id_fkey
        FOREIGN KEY (operator_id) REFERENCES operator (id),
    CONSTRAINT from_operator_id_fkey
        FOREIGN KEY (from_operator_id) REFERENCES operator (id),
    CONSTRAINT to_operator_id_fkey
        FOREIGN KEY (to_operator_id) REFERENCES operator (id),
    CONSTRAINT reservation_status_id_fkey
        FOREIGN KEY (reservation_status_id) REFERENCES reservation_status (id)
);

-- Apply Permissions
ALTER TABLE reservation_operator_log OWNER TO postgres;
GRANT ALL ON TABLE reservation_operator_log TO postgres;
GRANT ALL ON TABLE reservation_operator_log TO www;
GRANT SELECT ON TABLE reservation_operator_log TO perlydev;
GRANT USAGE ON SEQUENCE reservation_operator_log_id_seq TO postgres;
GRANT USAGE ON SEQUENCE reservation_operator_log_id_seq TO www;
GRANT USAGE ON SEQUENCE reservation_operator_log_id_seq TO perlydev;

-- Create Indexes
CREATE INDEX idx_reservation_operator_log_reservation_id
    ON reservation_operator_log (reservation_id);

COMMIT;
