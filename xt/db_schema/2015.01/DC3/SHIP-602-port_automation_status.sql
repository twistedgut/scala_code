-- Populate new carrier automation fields
BEGIN;
    ALTER TABLE shipment
        -- We set this to true and later switch it back to false - this is
        -- because this patch will run faster if we have fewer rows to update
        -- in the next statement, and the majority of shipments should have
        -- has_valid_address set to true
        ADD has_valid_address    BOOLEAN NOT NULL DEFAULT TRUE,
        ADD force_manual_booking BOOLEAN NOT NULL DEFAULT FALSE
    ;

    -- All DHL shipments with a destination code have a valid address
    -- All Premier shipments have a valid address
    UPDATE shipment
        SET has_valid_address = FALSE
        -- Use the negation of the statement that finds shipments with a valid
        -- address to identify false valid addresses
        WHERE NOT (
            ( destination_code != '' AND destination_code IS NOT NULL )
            OR shipment_type_id = ( SELECT id FROM shipment_type WHERE type = 'Premier' )
        )
        -- Sample shipments never get their addresses validated so their
        -- has_valid_address flag remains false
        OR shipment_class_id IN (
            SELECT id FROM shipment_class WHERE class IN ('Sample', 'Press', 'Transfer Shipment')
        )
    ;

    -- Set this default to what it should be
    ALTER TABLE shipment ALTER COLUMN has_valid_address SET DEFAULT FALSE;

    -- We force manual booking for all virtual voucher only shipments
    UPDATE shipment s
        SET force_manual_booking = TRUE
        WHERE EXISTS
            (SELECT 1
                FROM shipment_item si
                    LEFT JOIN voucher.variant vv ON si.voucher_variant_id = vv.id
                    LEFT JOIN voucher.product vp ON vv.voucher_product_id = vp.id AND NOT vp.is_physical
                WHERE si.shipment_id = s.id
                GROUP BY si.shipment_id
                HAVING count(vp.id) = count(si.id)
            )
    ;

    -- We force manual booking for all sample shipments
    UPDATE shipment s
        SET force_manual_booking = TRUE
        FROM shipment_class sc
        WHERE s.shipment_class_id = sc.id
        AND sc.class IN ('Sample', 'Press', 'Transfer Shipment')
    ;

COMMIT;
