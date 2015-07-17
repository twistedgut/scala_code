BEGIN;

UPDATE shipping_charge SET is_enabled = FALSE WHERE
    sku IN (
        '900025-002',
        '910025-001'
    );

COMMIT;
