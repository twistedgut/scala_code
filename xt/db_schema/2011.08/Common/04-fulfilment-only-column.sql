-- Add a 'fulfilment_only' attribute to the business table to help distinguish
-- third parties like JimmyChoo
BEGIN;

    -- Create new column
    ALTER TABLE business ADD COLUMN fulfilment_only BOOLEAN DEFAULT FALSE NOT NULL;

    UPDATE business SET fulfilment_only = true WHERE name = 'JIMMYCHOO.COM';

COMMIT;
