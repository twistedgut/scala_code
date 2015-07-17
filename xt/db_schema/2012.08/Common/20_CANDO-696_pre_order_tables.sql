BEGIN WORK;

CREATE TABLE pre_order_status (
    id                          SERIAL NOT NULL PRIMARY KEY,
    status                      CHARACTER VARYING(50) NOT NULL UNIQUE
);

INSERT INTO pre_order_status(status) VALUES
('Incomplete'),
('Payment Declined'),
('Complete'),
('Part Exported'),
('Exported'),
('Cancelled');

ALTER TABLE pre_order_status OWNER             TO postgres;
GRANT ALL ON TABLE pre_order_status            TO postgres;
GRANT ALL ON TABLE pre_order_status            TO www;
GRANT ALL ON SEQUENCE pre_order_status_id_seq  TO postgres;
GRANT ALL ON SEQUENCE pre_order_status_id_seq  TO www;


CREATE TABLE pre_order_item_status (
    id                          SERIAL NOT NULL PRIMARY KEY,
    status                      CHARACTER VARYING(50) NOT NULL UNIQUE
);

INSERT INTO pre_order_item_status(status) VALUES
('Selected'),
('Confirmed'),
('Payment Declined'),
('Complete'),
('Exported'),
('Cancelled');

ALTER TABLE pre_order_item_status OWNER             TO postgres;
GRANT ALL ON TABLE pre_order_item_status            TO postgres;
GRANT ALL ON TABLE pre_order_item_status            TO www;
GRANT ALL ON SEQUENCE pre_order_item_status_id_seq  TO postgres;
GRANT ALL ON SEQUENCE pre_order_item_status_id_seq  TO www;


CREATE TABLE pre_order (
    id                          SERIAL NOT NULL PRIMARY KEY,
    customer_id                 INTEGER NOT NULL REFERENCES customer(id),
    pre_order_status_id         INTEGER NOT NULL REFERENCES pre_order_status(id),
    reservation_source_id       INTEGER REFERENCES reservation_source(id),
    shipment_address_id         INTEGER NOT NULL REFERENCES order_address(id),
    invoice_address_id          INTEGER NOT NULL REFERENCES order_address(id),
    shipping_charge_id          INTEGER REFERENCES shipping_charge(id),
    packaging_type_id           INTEGER REFERENCES packaging_type(id),
    currency_id                 INTEGER NOT NULL REFERENCES currency(id),
    operator_id                 INTEGER NOT NULL REFERENCES operator(id),
    telephone_day               CHARACTER VARYING(255) NOT NULL,
    telephone_eve               CHARACTER VARYING(255),
    total_value                 NUMERIC(10,3),
    comment                     TEXT,
    created                     TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX pre_order_customer_idx ON pre_order(customer_id);
CREATE INDEX pre_order_status_idx   ON pre_order(pre_order_status_id);
CREATE INDEX pre_order_operator_idx ON pre_order(operator_id);

ALTER TABLE pre_order OWNER            TO postgres;
GRANT ALL ON TABLE pre_order           TO postgres;
GRANT ALL ON TABLE pre_order           TO www;
GRANT ALL ON SEQUENCE pre_order_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_id_seq TO www;


CREATE TABLE pre_order_payment (
    id                          SERIAL NOT NULL PRIMARY KEY,
    pre_order_id                INTEGER NOT NULL REFERENCES pre_order(id),
    preauth_ref                 CHARACTER VARYING(255) NOT NULL UNIQUE,
    settle_ref                  CHARACTER VARYING(255) UNIQUE,
    psp_ref                     CHARACTER VARYING(255) UNIQUE,
    fulfilled                   BOOLEAN NOT NULL DEFAULT FALSE,
    valid                       BOOLEAN NOT NULL DEFAULT TRUE
);

ALTER TABLE pre_order_payment OWNER            TO postgres;
GRANT ALL ON TABLE pre_order_payment           TO postgres;
GRANT ALL ON TABLE pre_order_payment           TO www;
GRANT ALL ON SEQUENCE pre_order_payment_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_payment_id_seq TO www;


CREATE TABLE pre_order_note_type (
    id                          SERIAL NOT NULL PRIMARY KEY,
    description                 CHARACTER VARYING(50) NOT NULL UNIQUE
);

INSERT INTO pre_order_note_type(description) VALUES
('Shipment Address Change'),
('Pre-Order Item'),
('Misc'),
('Online Fraud/Finance');

ALTER TABLE pre_order_note_type OWNER            TO postgres;
GRANT ALL ON TABLE pre_order_note_type           TO postgres;
GRANT ALL ON TABLE pre_order_note_type           TO www;
GRANT ALL ON SEQUENCE pre_order_note_type_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_note_type_id_seq TO www;

CREATE TABLE pre_order_note (
    id                          SERIAL NOT NULL PRIMARY KEY,
    pre_order_id                INTEGER NOT NULL REFERENCES pre_order(id),
    note                        TEXT NOT NULL,
    note_type_id                INTEGER NOT NULL REFERENCES pre_order_note_type(id),
    operator_id                 INTEGER NOT NULL REFERENCES operator(id),
    date                        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX pre_order_note_type_idx ON pre_order_note(note_type_id);
CREATE INDEX pre_order_note_pre_order_idx ON pre_order_note(note_type_id);

ALTER TABLE pre_order_note OWNER            TO postgres;
GRANT ALL ON TABLE pre_order_note           TO postgres;
GRANT ALL ON TABLE pre_order_note           TO www;
GRANT ALL ON SEQUENCE pre_order_note_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_note_id_seq TO www;


CREATE TABLE pre_order_status_log (
    id                          SERIAL NOT NULL PRIMARY KEY,
    pre_order_id                INTEGER NOT NULL REFERENCES pre_order(id),
    pre_order_status_id         INTEGER NOT NULL REFERENCES pre_order_status(id),
    operator_id                 INTEGER NOT NULL REFERENCES operator(id),
    date                        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE pre_order_status_log OWNER            TO postgres;
GRANT ALL ON TABLE pre_order_status_log           TO postgres;
GRANT ALL ON TABLE pre_order_status_log           TO www;
GRANT ALL ON SEQUENCE pre_order_status_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_status_log_id_seq TO www;


CREATE TABLE pre_order_item (
    id                          SERIAL NOT NULL PRIMARY KEY,
    pre_order_id                INTEGER NOT NULL REFERENCES pre_order(id),
    variant_id                  INTEGER NOT NULL REFERENCES variant(id),
    reservation_id              INTEGER REFERENCES reservation(id),
    pre_order_item_status_id    INTEGER NOT NULL REFERENCES pre_order_item_status(id),
    tax                         NUMERIC(10,3) NOT NULL,
    duty                        NUMERIC(10,3) NOT NULL,
    unit_price                  NUMERIC(10,3) NOT NULL,
    created                     TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX pre_order_item_variant_idx     ON pre_order_item(variant_id);
CREATE INDEX pre_order_item_reservation_idx ON pre_order_item(reservation_id);

ALTER TABLE pre_order_item OWNER            TO postgres;
GRANT ALL ON TABLE pre_order_item           TO postgres;
GRANT ALL ON TABLE pre_order_item           TO www;
GRANT ALL ON SEQUENCE pre_order_item_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_item_id_seq TO www;


CREATE TABLE pre_order_item_status_log (
    id                          SERIAL NOT NULL PRIMARY KEY,
    pre_order_item_id           INTEGER NOT NULL REFERENCES pre_order_item(id),
    pre_order_item_status_id    INTEGER NOT NULL REFERENCES pre_order_item_status(id),
    operator_id                 INTEGER NOT NULL REFERENCES operator(id),
    date                        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE pre_order_item_status_log OWNER            TO postgres;
GRANT ALL ON TABLE pre_order_item_status_log           TO postgres;
GRANT ALL ON TABLE pre_order_item_status_log           TO www;
GRANT ALL ON SEQUENCE pre_order_item_status_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_item_status_log_id_seq TO www;

COMMIT WORK;
