-- CANDO-3302: Add a flag to the 'orders.payment_method'
--             table to indicate that the PSP should be
--             notified if a change of Address occurs

BEGIN WORK;

-- Add the new Column
ALTER TABLE orders.payment_method
    ADD COLUMN notify_psp_of_address_change BOOLEAN NOT NULL DEFAULT FALSE
;

-- Update the PayPal method
UPDATE orders.payment_method
    SET notify_psp_of_address_change = TRUE
WHERE payment_method = 'PayPal'
;

COMMIT WORK;
