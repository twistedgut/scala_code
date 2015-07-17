BEGIN;

    -- update the list of Shipping-SKUS considered 'express'
    UPDATE shipping_charge
        SET is_express = FALSE
        WHERE sku IN (
            '9000200-001',
            '9000201-001',
            '910000-001',
            '910004-001',
            '910008-001',
            '903008-001',
            '903009-001',
            '903003-001',
            '903006-001',
            '903007-001',
            '903000-001',
            '900000-001',
            '900008-001',
            '900004-001'
        )
    ;

    UPDATE shipping_charge
        SET is_express = TRUE
        WHERE sku IN (
            '9000420-008',
            '910003-008',
            '9000524-004',
            '910003-002',
            '910003-003',
            '910003-004',
            '910003-005',
            '910003-007',
            '910003-006',
            '9000522-002',
            '9000523-003',
            '9000525-005',
            '9000526-006',
            '9000527-007',
            '9000429-009',
            '9000430-010',
            '9000431-011',
            '9000432-012',
            '9000433-013',
            '9000434-014',
            '9000435-015',
            '9000436-016',
            '9000437-017',
            '9000438-018',
            '910003-009',
            '910003-010',
            '910003-011',
            '910003-012',
            '910003-013',
            '910003-014',
            '910003-015',
            '910003-016',
            '910003-017',
            '910003-018'
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