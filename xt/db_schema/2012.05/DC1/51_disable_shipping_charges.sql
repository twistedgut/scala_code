BEGIN;

UPDATE shipping_charge SET is_enabled = FALSE WHERE
    sku IN (
        '900001-001',
        '900002-001',
        '900005-001',
        '910001-001',
        '910002-001',
        '910005-001'
    );

COMMIT;
