BEGIN;
    DELETE FROM customer WHERE is_customer_number IS NULL;
    ALTER TABLE customer
        ALTER COLUMN is_customer_number SET NOT NULL
    ;
COMMIT;
