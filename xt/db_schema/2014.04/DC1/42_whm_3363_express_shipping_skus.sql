BEGIN;

    -- WHM-3363: Update express shipping skus to have enabled is_express flag

    UPDATE shipping_charge
        SET is_express = TRUE
        WHERE sku IN (
            '900000-001',
            '900003-001',
            '900004-001',
            '900008-001',
            '9000200-001',
            '9000201-001',
            '910000-001',
            '910003-001',
            '910004-001',
            '910008-001',
            '903000-001',
            '903003-001',
            '903006-001',
            '903007-001',
            '903008-001',
            '903009-001'
        );

COMMIT;