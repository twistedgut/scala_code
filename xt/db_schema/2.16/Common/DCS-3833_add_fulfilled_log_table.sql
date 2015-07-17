-- DCS-3833: Create a log table to log the changes to the fulfilled flag on the
--           'orders.payment' table

BEGIN WORK;

CREATE TABLE orders.log_payment_fulfilled_change (
    id SERIAL NOT NULL,
    payment_id INTEGER NOT NULL REFERENCES orders.payment(id),
    new_state BOOLEAN NOT NULL,
    date_changed TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT ('now'::text)::timestamp(6) WITH TIME ZONE,
    operator_id INTEGER NOT NULL REFERENCES public.operator(id),
    reason_for_change CHARACTER VARYING(255),
    CONSTRAINT log_payment_fulfilled_change_pkey PRIMARY KEY (id)
)
;
CREATE INDEX idx_log_payment_fulfilled_change_payment_id ON orders.log_payment_fulfilled_change(payment_id);

ALTER TABLE orders.log_payment_fulfilled_change OWNER TO postgres;
GRANT ALL ON TABLE orders.log_payment_fulfilled_change TO postgres;
GRANT ALL ON TABLE orders.log_payment_fulfilled_change TO www;

GRANT ALL ON TABLE orders.log_payment_fulfilled_change_id_seq TO postgres;
GRANT ALL ON TABLE orders.log_payment_fulfilled_change_id_seq TO www;

COMMIT WORK;
