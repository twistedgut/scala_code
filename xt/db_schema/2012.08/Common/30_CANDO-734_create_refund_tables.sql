-- CANDO-734: Adds tables required to refund a Pre-Order

BEGIN WORK;

--
-- Pre-Order Refund Status
--
CREATE TABLE pre_order_refund_status (
    id          SERIAL NOT NULL PRIMARY KEY,
    status      CHARACTER VARYING(255) UNIQUE NOT NULL
)
;
ALTER TABLE pre_order_refund_status OWNER TO postgres;
GRANT ALL ON TABLE pre_order_refund_status TO postgres;
GRANT ALL ON TABLE pre_order_refund_status TO www;
GRANT ALL ON SEQUENCE pre_order_refund_status_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_refund_status_id_seq TO www;

-- populate it
INSERT INTO pre_order_refund_status (status) VALUES ('Pending');
INSERT INTO pre_order_refund_status (status) VALUES ('Failed');
INSERT INTO pre_order_refund_status (status) VALUES ('Complete');
INSERT INTO pre_order_refund_status (status) VALUES ('Cancelled');


--
-- Pre-Order Refund
--
CREATE TABLE pre_order_refund (
    id                          SERIAL NOT NULL PRIMARY KEY,
    pre_order_id                INTEGER NOT NULL REFERENCES pre_order(id),
    pre_order_refund_status_id  INTEGER NOT NULL REFERENCES pre_order_refund_status(id),
    sent_to_psp                 BOOLEAN NOT NULL DEFAULT FALSE
)
;
ALTER TABLE pre_order_refund OWNER TO postgres;
GRANT ALL ON TABLE pre_order_refund TO postgres;
GRANT ALL ON TABLE pre_order_refund TO www;
GRANT ALL ON SEQUENCE pre_order_refund_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_refund_id_seq TO www;


--
-- Pre-Order Refund Item
--
CREATE TABLE pre_order_refund_item (
    id                          SERIAL NOT NULL PRIMARY KEY,
    pre_order_refund_id         INTEGER NOT NULL REFERENCES pre_order_refund(id),
    pre_order_item_id           INTEGER NOT NULL REFERENCES pre_order_item(id),
    unit_price                  NUMERIC(10,3) NOT NULL,
    tax                         NUMERIC(10,3) NOT NULL,
    duty                        NUMERIC(10,3) NOT NULL
)
;
ALTER TABLE pre_order_refund_item OWNER TO postgres;
GRANT ALL ON TABLE pre_order_refund_item TO postgres;
GRANT ALL ON TABLE pre_order_refund_item TO www;
GRANT ALL ON SEQUENCE pre_order_refund_item_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_refund_item_id_seq TO www;


--
-- Pre-Order Refund Status Log
--
CREATE TABLE pre_order_refund_status_log (
    id                          SERIAL NOT NULL PRIMARY KEY,
    pre_order_refund_id         INTEGER NOT NULL REFERENCES pre_order_refund(id),
    pre_order_refund_status_id  INTEGER NOT NULL REFERENCES pre_order_refund_status(id),
    operator_id                 INTEGER NOT NULL REFERENCES operator(id),
    date                        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
)
;
ALTER TABLE pre_order_refund_status_log OWNER TO postgres;
GRANT ALL ON TABLE pre_order_refund_status_log TO postgres;
GRANT ALL ON TABLE pre_order_refund_status_log TO www;
GRANT ALL ON SEQUENCE pre_order_refund_status_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_refund_status_log_id_seq TO www;

--
-- Pre-Order Refund Failed Log
--
CREATE TABLE pre_order_refund_failed_log (
    id                          SERIAL NOT NULL PRIMARY KEY,
    pre_order_refund_id         INTEGER NOT NULL REFERENCES pre_order_refund(id),
    preauth_ref_used            CHARACTER VARYING(255),
    failure_message             TEXT NOT NULL,
    operator_id                 INTEGER NOT NULL REFERENCES operator(id),
    date                        TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
)
;
ALTER TABLE pre_order_refund_failed_log OWNER TO postgres;
GRANT ALL ON TABLE pre_order_refund_failed_log TO postgres;
GRANT ALL ON TABLE pre_order_refund_failed_log TO www;
GRANT ALL ON SEQUENCE pre_order_refund_failed_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE pre_order_refund_failed_log_id_seq TO www;


COMMIT WORK;
