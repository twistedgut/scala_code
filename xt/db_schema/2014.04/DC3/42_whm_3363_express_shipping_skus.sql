BEGIN;

    -- WHM-3363: Update express shipping skus to have enabled is_express flag

    UPDATE shipping_charge
        SET is_express = TRUE
        WHERE sku IN (
            '9000311-001',
            '9000312-001',
            '9000313-001',
            '9000314-001',
            '9000321-001'
        );

COMMIT;