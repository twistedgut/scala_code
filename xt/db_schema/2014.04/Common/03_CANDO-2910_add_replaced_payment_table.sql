-- CANDO-2910: Add a new table to store Replaced Payments
--             when they get overwritten when creating a
--             new Pre-Auth

BEGIN WORK;

CREATE TABLE orders.replaced_payment (
    id                  SERIAL PRIMARY KEY,
    orders_id           INTEGER NOT NULL REFERENCES public.orders(id),
    psp_ref             CHARACTER VARYING (255) NOT NULL,
    preauth_ref         CHARACTER VARYING (255) NOT NULL,
    settle_ref          CHARACTER VARYING (255),
    fulfilled           BOOLEAN NOT NULL,
    valid               BOOLEAN NOT NULL,
    payment_method_id   INTEGER NOT NULL REFERENCES orders.payment_method(id),
    date_replaced       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE orders.replaced_payment OWNER TO postgres;
GRANT ALL ON TABLE orders.replaced_payment TO www;
GRANT ALL ON SEQUENCE orders.replaced_payment_id_seq TO www;

CREATE INDEX idx_replaced_payment_orders_id ON orders.replaced_payment(orders_id);
CREATE INDEX idx_replaced_payment_psp_ref ON orders.replaced_payment(psp_ref);
CREATE INDEX idx_replaced_payment_preauth_ref ON orders.replaced_payment(preauth_ref);

COMMIT WORK;
