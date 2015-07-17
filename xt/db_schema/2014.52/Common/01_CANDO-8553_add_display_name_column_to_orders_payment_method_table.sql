-- CANDO-8553: This patch adds an additional column to the
-- 'orders.payment_method' table called 'display_name', to store a separate
-- human readable description of the payment method for use in templates. It
-- just so happens the ones currently available are already human readable, so
-- this is mainly provided as future proofing

BEGIN WORK;

ALTER TABLE     orders.payment_method
ADD COLUMN      display_name varchar(255);

UPDATE          orders.payment_method
SET             display_name = payment_method;

ALTER TABLE     orders.payment_method
ALTER COLUMN    display_name SET NOT NULL;

COMMIT;
