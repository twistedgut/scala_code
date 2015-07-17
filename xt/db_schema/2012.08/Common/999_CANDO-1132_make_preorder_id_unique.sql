BEGIN WORK;

ALTER TABLE pre_order_payment ADD CONSTRAINT pre_order_payment_pre_order_id_unique UNIQUE (pre_order_id);

COMMIT WORK;
