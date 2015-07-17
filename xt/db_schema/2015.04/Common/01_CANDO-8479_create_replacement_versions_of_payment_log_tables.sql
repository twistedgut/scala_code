-- CANDO-8479: Create new Log tables to copy existing Log records for 'orders.payment' to
--             when an 'orders.payment' record is moved to the 'orders.replaced_payment' table

BEGIN WORK;

--
-- Create 'orders.log_replaced_payment_preauth_cancellation'
--

CREATE TABLE orders.log_replaced_payment_preauth_cancellation (
    id                          SERIAL NOT NULL PRIMARY KEY,
    replaced_payment_id         INTEGER NOT NULL REFERENCES orders.replaced_payment(id),
    cancelled                   BOOLEAN NOT NULL,
    preauth_ref_cancelled       CHARACTER VARYING(255) NOT NULL,
    context                     CHARACTER VARYING(255) NOT NULL,
    message                     TEXT,
    date                        TIMESTAMP WITH TIME ZONE NOT NULL,
    operator_id                 INTEGER NOT NULL REFERENCES public.operator(id)
);
CREATE INDEX idx_log_replaced_payment_preauth_cancellation_preauth_ref ON orders.log_replaced_payment_preauth_cancellation(preauth_ref_cancelled);

ALTER TABLE orders.log_replaced_payment_preauth_cancellation OWNER TO postgres;
GRANT ALL ON TABLE orders.log_replaced_payment_preauth_cancellation TO postgres;
GRANT ALL ON TABLE orders.log_replaced_payment_preauth_cancellation TO www;
GRANT ALL ON TABLE orders.log_replaced_payment_preauth_cancellation_id_seq TO postgres;
GRANT ALL ON TABLE orders.log_replaced_payment_preauth_cancellation_id_seq TO www;


--
-- Create 'orders.log_replaced_payment_fulfilled_change'
--

CREATE TABLE orders.log_replaced_payment_fulfilled_change (
    id                      SERIAL NOT NULL PRIMARY KEY,
    replaced_payment_id     INTEGER NOT NULL REFERENCES orders.replaced_payment(id),
    new_state               BOOLEAN NOT NULL,
    date_changed            TIMESTAMP WITH TIME ZONE NOT NULL,
    operator_id             INTEGER NOT NULL REFERENCES public.operator(id),
    reason_for_change       CHARACTER VARYING(255)
)
;
CREATE INDEX idx_log_replaced_payment_fulfilled_change_replaced_payment_id ON orders.log_replaced_payment_fulfilled_change(replaced_payment_id);

ALTER TABLE orders.log_replaced_payment_fulfilled_change OWNER TO postgres;
GRANT ALL ON TABLE orders.log_replaced_payment_fulfilled_change TO postgres;
GRANT ALL ON TABLE orders.log_replaced_payment_fulfilled_change TO www;
GRANT ALL ON TABLE orders.log_replaced_payment_fulfilled_change_id_seq TO postgres;
GRANT ALL ON TABLE orders.log_replaced_payment_fulfilled_change_id_seq TO www;


--
-- Create 'orders.log_replaced_payment_valid_change'
--

CREATE TABLE orders.log_replaced_payment_valid_change (
    id                      SERIAL PRIMARY KEY,
    replaced_payment_id     INTEGER NOT NULL REFERENCES orders.replaced_payment(id),
    date_changed            TIMESTAMP WITH TIME ZONE NOT NULL,
    new_state               BOOLEAN NOT NULL
);
CREATE INDEX orders_log_replaced_payment_valid_change_replaced_payment_id_idx ON orders.log_replaced_payment_valid_change( replaced_payment_id );

ALTER TABLE orders.log_replaced_payment_valid_change OWNER TO postgres;
GRANT ALL ON TABLE orders.log_replaced_payment_valid_change TO postgres;
GRANT ALL ON TABLE orders.log_replaced_payment_valid_change TO www;
GRANT ALL ON SEQUENCE orders.log_replaced_payment_valid_change_id_seq TO postgres;
GRANT ALL ON SEQUENCE orders.log_replaced_payment_valid_change_id_seq TO www;


COMMIT WORK;
