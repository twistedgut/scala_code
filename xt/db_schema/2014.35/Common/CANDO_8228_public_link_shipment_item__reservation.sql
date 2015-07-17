-- CANDO-8228: Add last-updated timestamp to link_shipment_item__reservation

BEGIN WORK;

ALTER
TABLE link_shipment_item__reservation
  ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    ;

COMMIT WORK;
