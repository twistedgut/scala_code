BEGIN;

    -- update the list of Shipping-SKUS considered 'express'
    UPDATE shipping_charge
        SET is_express = FALSE
        WHERE sku IN (
            '900014-001',
            '900013-001',
            '900012-001',
            '910012-001',
            '910013-001',
            '910014-001',
            '9000203-001',
            '904001-001',
            '904002-001',
            '904003-001',
            '904004-001'
        )
    ;

    UPDATE shipping_charge
        SET is_express = TRUE
        WHERE sku IN (
            '9010100-001',
            '9010102-001',
            '9010104-001',
            '9010106-001',
            '9010108-001',
            '9010110-001',
            '9010112-001',
            '9010114-001',
            '9010116-001'
        )
    ;

    INSERT INTO sos.processing_time (class_attribute_id, processing_time) VALUES
        ( (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Express'), '02:30:00')
    ;

    -- The 'express' processing_time overrides 'Standard'
    INSERT INTO sos.processing_time_override (major_id, minor_id) VALUES
        (
            (
                SELECT id
                FROM sos.processing_time
                WHERE class_attribute_id = (
                    SELECT id FROM sos.shipment_class_attribute WHERE name = 'Express'
                )
            ),
            (
                SELECT id
                FROM sos.processing_time
                WHERE class_id = (
                    SELECT id FROM sos.shipment_class WHERE name = 'Standard'
                )
            )
        )
    ;

COMMIT;