-- CANDO-8228: Add last-updated timestamp to link_shipment_item__promotion

BEGIN WORK;

ALTER
TABLE link_shipment_item__promotion
  ADD COLUMN last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    ;

COMMIT WORK;
