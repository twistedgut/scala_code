-- Story:       CANDO-1667
-- Sub-Task:    CANDO-1696
-- Description: Create a log table for orders.payment

BEGIN WORK;

CREATE TABLE orders.log_payment_valid_change (
    id              SERIAL PRIMARY KEY,
    payment_id      integer NOT NULL REFERENCES orders.payment(id),
    date_changed    timestamp WITH TIME ZONE NOT NULL DEFAULT now(),
    new_state       boolean NOT NULL
);

CREATE INDEX orders_log_payment_valid_change_payment_id_idx ON orders.log_payment_valid_change( payment_id );
ALTER TABLE orders.log_payment_valid_change OWNER TO postgres;
GRANT ALL ON TABLE orders.log_payment_valid_change TO www;
GRANT ALL ON SEQUENCE orders.log_payment_valid_change_id_seq TO www;

COMMIT;
