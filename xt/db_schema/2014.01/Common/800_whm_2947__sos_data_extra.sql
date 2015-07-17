BEGIN;

ALTER TABLE sos.shipment_class ADD COLUMN description TEXT NULL;
UPDATE sos.shipment_class SET description = 'A 3rd-party service that delivers worldwide' WHERE name = 'Standard';
UPDATE sos.shipment_class SET description = 'Faster service for locations in the same city as DCs, delivered by NAP-owned van' WHERE name = 'Premier';
UPDATE sos.shipment_class SET description = 'Staff orders delivered to our offices by NAP-owned van. Lower priority than customer orders' WHERE name = 'Staff';
UPDATE sos.shipment_class SET description = 'Used for samples. Stock samples are "transferred" from DC to studio and back in NAP-owned vans' WHERE name = 'Transfer';

ALTER TABLE sos.shipment_class ALTER COLUMN description SET NOT NULL;

COMMIT;
