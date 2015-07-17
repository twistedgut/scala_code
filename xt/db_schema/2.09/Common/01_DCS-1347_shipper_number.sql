-- Add 'shipper_number' field to 'shipping_account' table

BEGIN WORK;

ALTER TABLE shipping_account ADD COLUMN shipping_number CHARACTER VARYING(255);

COMMIT WORK;
