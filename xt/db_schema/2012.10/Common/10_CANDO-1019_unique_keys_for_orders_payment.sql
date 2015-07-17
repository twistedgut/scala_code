BEGIN WORK;

ALTER TABLE orders.payment DROP CONSTRAINT payment_preauth_ref_key;
ALTER TABLE orders.payment DROP CONSTRAINT payment_psp_ref_key;

ALTER TABLE orders.payment ADD CONSTRAINT payment_orders_psp_ref_key     UNIQUE (orders_id, psp_ref);
ALTER TABLE orders.payment ADD CONSTRAINT payment_orders_preauth_ref_key UNIQUE (orders_id, preauth_ref);

CREATE INDEX payment_preauth_ref_idx ON orders.payment(psp_ref);
CREATE INDEX payment_psp_ref_idx     ON orders.payment(preauth_ref);

COMMIT WORK;
