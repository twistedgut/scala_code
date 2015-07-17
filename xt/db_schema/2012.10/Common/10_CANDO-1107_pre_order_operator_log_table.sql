BEGIN WORK;


CREATE TABLE pre_order_operator_log (
    id                      SERIAL NOT NULL PRIMARY KEY,
    pre_order_id            INTEGER NOT NULL REFERENCES pre_order(id),
    pre_order_status_id     INTEGER NOT NULL REFERENCES pre_order_status(id),
    operator_id             INTEGER NOT NULL REFERENCES operator(id),
    from_operator_id        INTEGER NOT NULL REFERENCES operator(id),
    to_operator_id          INTEGER NOT NULL REFERENCES operator(id),
    created                 TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE pre_order_operator_log OWNER             TO postgres;
GRANT ALL ON TABLE pre_order_operator_log            TO postgres;
GRANT ALL ON TABLE pre_order_operator_log            TO www;
GRANT ALL ON SEQUENCE pre_order_operator_log_id_seq  TO postgres;
GRANT ALL ON SEQUENCE pre_order_operator_log_id_seq  TO www;

CREATE INDEX pre_order_operator_log__pre_order_id_idx ON pre_order_operator_log(pre_order_id);
CREATE INDEX pre_order_operator_log__bgy_operator_id_idx ON pre_order_operator_log(operator_id);

COMMIT WORK;
