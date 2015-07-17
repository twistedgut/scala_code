-- CANDO-47: Create a table to log the attempts at cancelling a Pre-Auth

BEGIN WORK;

CREATE TABLE orders.log_payment_preauth_cancellation (
    id SERIAL NOT NULL PRIMARY KEY,
    orders_payment_id INTEGER NOT NULL REFERENCES orders.payment(id),
    cancelled BOOLEAN NOT NULL,
    preauth_ref_cancelled CHARACTER VARYING(255) NOT NULL,
    context CHARACTER VARYING(255) NOT NULL,
    message TEXT,
    date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    operator_id INTEGER NOT NULL REFERENCES public.operator(id)
)
;

CREATE INDEX idx_log_payment_preauth_cancellation_preauth_ref ON orders.log_payment_preauth_cancellation (preauth_ref_cancelled);

ALTER TABLE orders.log_payment_preauth_cancellation OWNER TO postgres;
GRANT ALL ON TABLE orders.log_payment_preauth_cancellation TO postgres;
GRANT ALL ON TABLE orders.log_payment_preauth_cancellation TO www;
GRANT ALL ON TABLE orders.log_payment_preauth_cancellation_id_seq TO postgres;
GRANT ALL ON TABLE orders.log_payment_preauth_cancellation_id_seq TO www;

COMMIT WORK;
