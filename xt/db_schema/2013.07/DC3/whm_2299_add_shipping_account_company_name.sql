-- Add 'from_company_name' to shipping_account table

BEGIN WORK;

ALTER TABLE shipping_account ADD from_company_name TEXT;

UPDATE shipping_account SET from_company_name = 'The NET-A-PORTER Group Asia Pacific';

COMMIT WORK;
