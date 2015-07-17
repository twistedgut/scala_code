BEGIN;

-- Create a nullable urn and last_modified columns to map local customer and
-- address records to those in the central customer service
-- Add nullable customer title to the order_address.

ALTER TABLE customer ADD account_urn varchar(255) NULL DEFAULT NULL;
ALTER TABLE order_address ADD urn varchar(255) NULL DEFAULT NULL;
ALTER TABLE order_address ADD last_modified timestamp with time zone NULL DEFAULT NULL;
ALTER TABLE order_address ADD title varchar(255) NULL DEFAULT NULL;

COMMIT;
