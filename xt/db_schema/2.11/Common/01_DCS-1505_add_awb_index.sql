-- Add index to the shipment table for the outward AWB so that
-- they can be searched on for the dispatch screen which can now
-- take a Outward AWB as well as a Shipment Id.

BEGIN WORK;

CREATE INDEX shipment_outward_awb_idx ON shipment ( outward_airway_bill );

COMMIT WORK;
