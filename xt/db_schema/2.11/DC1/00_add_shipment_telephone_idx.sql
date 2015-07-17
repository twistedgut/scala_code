-- Add telephone index on the shipment table to make it inline with DC2

BEGIN WORK;

CREATE INDEX idx_shipment_telephone ON shipment ( telephone );

COMMIT WORK;
