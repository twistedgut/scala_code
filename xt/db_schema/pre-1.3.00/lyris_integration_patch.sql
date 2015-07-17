-- Purpose:
--  

BEGIN;

-- Add marketing contact opt out field to customer table
alter table customer add column no_marketing_contact timestamp null;

COMMIT;