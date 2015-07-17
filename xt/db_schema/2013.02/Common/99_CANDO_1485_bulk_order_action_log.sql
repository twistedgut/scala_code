BEGIN WORK;

CREATE TABLE bulk_order_action (
    id                          SERIAL NOT NULL PRIMARY KEY,
    name                        CHARACTER VARYING(255) NOT NULL,
    UNIQUE(name)
);

ALTER TABLE bulk_order_action OWNER TO postgres;
GRANT ALL ON TABLE bulk_order_action TO postgres;
GRANT ALL ON TABLE bulk_order_action TO www;

GRANT ALL ON SEQUENCE bulk_order_action_id_seq TO postgres;
GRANT ALL ON SEQUENCE bulk_order_action_id_seq TO www;

INSERT INTO bulk_order_action (name)
VALUES  ('Credit Hold to Accept'),
        ('Accept to Credit Hold');


CREATE TABLE bulk_order_action_log (
    id                          SERIAL NOT NULL PRIMARY KEY,
    action_id                   INTEGER NOT NULL REFERENCES public.bulk_order_action(id),
    date                        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE bulk_order_action_log OWNER TO postgres;
GRANT ALL ON TABLE bulk_order_action_log TO postgres;
GRANT ALL ON TABLE bulk_order_action_log TO www;

GRANT ALL ON SEQUENCE bulk_order_action_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE bulk_order_action_log_id_seq TO www;

CREATE INDEX bulk_order_action_log__action_idx ON bulk_order_action_log(action_id);

ALTER TABLE order_status_log
ADD COLUMN bulk_order_action_log_id INTEGER REFERENCES public.bulk_order_action_log(id) DEFAULT NULL;

COMMIT WORK;

