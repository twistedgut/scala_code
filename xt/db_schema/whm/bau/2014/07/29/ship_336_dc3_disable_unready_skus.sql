BEGIN;

    -- Disable these shipping skus that do not exist in the front-end yet
    UPDATE shipping_charge
        SET is_enabled = FALSE
        WHERE sku IN (
            '9000325-001'
        );

COMMIT;