
-- FLEX-661
--
-- Mark Shipping Charges as to whether they support free return
-- shipments
--

BEGIN WORK;


-- When the customer requests a return, is the return shipment free or
-- charged for
ALTER TABLE shipping_charge
    ADD COLUMN is_return_shipment_free BOOLEAN DEFAULT TRUE;



COMMIT WORK;

