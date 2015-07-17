BEGIN;

-- FLEX-583
-- Add indexes to make Premier Routing Export queries performant

CREATE INDEX idx_shipment_shipping_charge  ON shipment (shipping_charge_id);
CREATE INDEX idx_shipment_premier_routing  ON shipment (premier_routing_id);
CREATE INDEX idx_shipment_shipment_type    ON shipment (shipment_type_id);
CREATE INDEX idx_shipment_shipment_address ON shipment (shipment_address_id);

CREATE INDEX idx_return_shipment           ON return (shipment_id);

CREATE INDEX idx_customer_category         ON customer (category_id);

COMMIT;
