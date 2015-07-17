
--CANDO-8491:  Prevent Editing of Shipping Address after Settlement


BEGIN WORK;

ALTER TABLE orders.payment_method
    ADD COLUMN  allow_editing_of_shipping_address_after_settlement BOOLEAN NOT NULL DEFAULT TRUE
;


COMMENT ON COLUMN orders.payment_method.allow_editing_of_shipping_address_after_settlement IS 'SET to FALSE if the Payment Method does not allow Shipping Address to be changed after settlement.';


UPDATE orders.payment_method
 SET  allow_editing_of_shipping_address_after_settlement='FALSE'
WHERE payment_method='Klarna'
;

COMMIT WORK;
