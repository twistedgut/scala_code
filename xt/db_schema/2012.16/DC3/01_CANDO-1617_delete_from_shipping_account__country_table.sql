-- CANDO-1617: Delete all records from 'shipping_account__country' table

BEGIN WORK;

DELETE FROM shipping_account__country;

COMMIT WORK;
