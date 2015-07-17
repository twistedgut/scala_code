--CANDO-942 : Delivery Signature opt in/out option

BEGIN;

ALTER TABLE pre_order
    ADD COLUMN signature_required BOOLEAN DEFAULT TRUE NOT NULL;

COMMIT;
