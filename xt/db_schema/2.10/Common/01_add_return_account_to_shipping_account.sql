-- Add a new column 'return_account_number' to 'shipping_account' table

BEGIN WORK;

ALTER TABLE shipping_account
    ADD COLUMN return_account_number CHARACTER VARYING(255)
;

COMMIT WORK;
