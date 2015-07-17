-- Removes the 'charge_id' field from the Shipment table.

-- Please speak to Jason Tang and/or the Flexi Shipping team
-- about why this field was there and how now been removed.

-- PLEASE NOTE: This is not to be confused with the 'shipping_charge_id' field.

BEGIN WORK;

ALTER TABLE shipment
    DROP COLUMN charge_id
;

COMMIT WORK;
