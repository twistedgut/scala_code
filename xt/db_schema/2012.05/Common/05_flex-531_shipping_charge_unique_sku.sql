
-- FLEX-31
--
-- Add unique constraint to shipping_charge.sku . Because that's the
-- shape of the data.



BEGIN WORK;



ALTER TABLE shipping_charge
    ADD CONSTRAINT unique_shipping_charge_sku UNIQUE (sku);



COMMIT WORK;

