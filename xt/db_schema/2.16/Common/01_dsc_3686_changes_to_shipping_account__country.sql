BEGIN;

-- removing constraint that stops me having multiple records for channels
ALTER TABLE shipping_account__country
    DROP CONSTRAINT shipping_account__country_country_key;

-- it makes sense to have a combined key here
ALTER TABLE shipping_account__country
    ADD CONSTRAINT shipping_account__shipping_acc_country_channel_key
        UNIQUE (shipping_account_id,country,channel_id);


COMMIT;
