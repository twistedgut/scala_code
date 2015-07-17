-- CANDO-8228: Add last-updated timestamp to link_shipment__promotion

BEGIN WORK;

ALTER
TABLE link_shipment__promotion
  ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    ;

COMMIT WORK;
