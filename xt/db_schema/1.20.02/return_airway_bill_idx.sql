-- Create indexes on return_airway_bill in shipment and return_item tables to
-- speed up return_arrivals/booking in searches

BEGIN;
    CREATE INDEX idx_shipment_return_airway_bill
        ON shipment(return_airway_bill);
    CREATE INDEX idx_return_item_return_airway_bill
        ON return_item(return_airway_bill);
COMMIT;
