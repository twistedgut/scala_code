BEGIN;

UPDATE shipment SET premier_routing_id = 0;
ALTER TABLE shipment ALTER COLUMN premier_routing_id SET NOT NULL;
ALTER TABLE shipment ALTER COLUMN premier_routing_id SET DEFAULT 0;

ALTER TABLE premier_routing ADD COLUMN code varchar(1);

UPDATE premier_routing SET code = 'A', description = 'Anytime before 8pm today' WHERE id = 1; 
UPDATE premier_routing SET code = 'B', description = 'Within business hours' WHERE id = 2; 
UPDATE premier_routing SET code = 'C', description = 'Contact customer to arrange a time' WHERE id = 0; 

ALTER TABLE premier_routing ALTER COLUMN code SET not null;

COMMIT;