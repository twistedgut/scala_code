-- How did we miss adding this index?!

BEGIN;
    CREATE INDEX allocation_shipment_id_idx ON allocation(shipment_id);
COMMIT;
