-- need to be able to store the operator responsible for the qc failure against the item
BEGIN;

    DELETE from shipment_extra_item;

    ALTER TABLE shipment_extra_item ADD COLUMN
        operator_id integer NOT NULL references operator(id);

COMMIT;
