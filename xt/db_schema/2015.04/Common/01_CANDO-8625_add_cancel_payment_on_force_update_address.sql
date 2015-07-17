-- CANDO-8625: Add a new column to the 'orders.payment_method' table
--             called 'cancel_payment_after_force_address_update'

BEGIN WORK;

ALTER TABLE orders.payment_method
    ADD COLUMN cancel_payment_after_force_address_update BOOLEAN NOT NULL DEFAULT FALSE
;

COMMENT ON COLUMN orders.payment_method.cancel_payment_after_force_address_update IS 'Some Third Party Payment Methods (Klarna) will require the Payment to be Cancelled if an Operator uses the Force Change of Address option when editing the Shipping Address and the Provider rejects the new Address.';

UPDATE orders.payment_method
    SET  cancel_payment_after_force_address_update = 'TRUE'
WHERE   payment_method = 'Klarna'
;

COMMIT WORK;
