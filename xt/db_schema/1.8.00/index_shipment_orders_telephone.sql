-- Used to speed up searches on telephone numbers in the orders and shipment
-- tables
BEGIN;
    
CREATE INDEX idx_orders_telephone ON orders(telephone);
CREATE INDEX idx_shipment_telephone ON shipment(telephone);
CREATE INDEX idx_orders_mobile_telephone ON orders(mobile_telephone);
CREATE INDEX idx_shipment_mobile_telephone ON orders(mobile_telephone);

COMMIT;
