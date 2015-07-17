BEGIN;

-- We're changing the primary key of shipment_item to varchar from INT to allow
-- us to have IDs with a prefixed C. This needs to be able to co-exist with the
-- old INT style. As a result, we also need to update the fields that reference
-- this...

-- Remove the constraint from the one referencing field
ALTER TABLE shipment_item DROP CONSTRAINT shipment_item_shipment_box_id_fkey;

-- Change the target colum
ALTER TABLE shipment_box  ALTER COLUMN id TYPE VARCHAR(32);
-- Change the referencing column
ALTER TABLE shipment_item ALTER COLUMN shipment_box_id TYPE VARCHAR(32);

-- Re-add the constraint
ALTER TABLE shipment_item ADD CONSTRAINT shipment_item_shipment_box_id_fkey
    FOREIGN KEY (shipment_box_id) REFERENCES shipment_box (id) DEFERRABLE;

COMMIT;