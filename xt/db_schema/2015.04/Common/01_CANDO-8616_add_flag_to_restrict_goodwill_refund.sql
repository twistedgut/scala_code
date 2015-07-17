-- CANDO-8616: Add column to 'orders.payment_method' table called
--             'allow_goodwill_refund_using_payment'

BEGIN WORK;

--
-- add a new column
--
ALTER TABLE orders.payment_method
    ADD COLUMN allow_goodwill_refund_using_payment BOOLEAN NOT NULL DEFAULT TRUE
;

-- add comments to the new fields
COMMENT ON COLUMN orders.payment_method.allow_goodwill_refund_using_payment IS 'When TRUE allows the creation of a pure Goodwill Refund which uses the ''misc_refund'' column on the ''renumeration'' table to be raised against the Payment used to pay for the Order such as a Credit Card (in other words allow a ''Card Refund'' invoice to be created). Set to FALSE when the Payment Method can''t handle pure Goodwill Refunds (such as Klarna).';

--
-- set it to be FALSE for Klarna
--
UPDATE orders.payment_method
    SET allow_goodwill_refund_using_payment = FALSE
WHERE payment_method = 'Klarna'
;

COMMIT WORK;
