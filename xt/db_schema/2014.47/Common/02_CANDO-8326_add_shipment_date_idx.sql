-- CANDO-8326: Add Index to 'shipment.date' field

BEGIN WORK;

CREATE INDEX idx_shipment_date ON shipment(date);

COMMIT WORK;
