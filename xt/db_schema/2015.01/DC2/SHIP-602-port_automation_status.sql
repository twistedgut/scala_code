-- Populate new carrier automation fields
BEGIN;
    -- Create new columns
    ALTER TABLE shipment
        -- We set this to true and later switch it back to false - this is
        -- because this patch will run faster if we have fewer rows to update
        -- in the next statement, and the majority of shipments should have
        -- has_valid_address set to true
        ADD has_valid_address    BOOLEAN NOT NULL DEFAULT TRUE,
        ADD force_manual_booking BOOLEAN NOT NULL DEFAULT FALSE
    ;

    -- Set valid addresses
    UPDATE shipment s
        SET has_valid_address = FALSE
        FROM shipment_type st
        -- UPS (identified with 'Domestic') shipments are false if they have a
        -- non-numeric value or a value < 0.90
        WHERE (
            s.shipment_type_id = st.id
            AND st.id = ( SELECT id FROM shipment_type WHERE type = 'Domestic' )
            -- A little shorthand, but anything with a digit in this column
            -- should be castable to a number without erroring
            AND NOT ( av_quality_rating ~ E'\\d' AND av_quality_rating::numeric >= 0.90 )
        -- DHL shipments (in practice undispatched only, as any DHL shipments
        -- that are dispatched have to have a destination code) are false if
        -- they don't have a destination code (empty string or undef)
        ) OR (
            s.shipment_type_id = st.id
            AND st.id IN ( SELECT id FROM shipment_type WHERE type IN ( 'International', 'International DDU' ) )
            AND ( destination_code = '' OR destination_code IS NULL )
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

    -- We force manual booking for all sample and some UPS shipments
    UPDATE shipment s
        SET force_manual_booking = TRUE
        FROM
            shipment_class sc,
            shipment_type st
        -- Sample shipments
        WHERE (
            s.shipment_class_id = sc.id
            AND sc.class IN ('Sample', 'Press', 'Transfer Shipment')
        -- UPS shipments that are not automated. This means we'll get some
        -- false positives with shipments that haven't been dispatched yet, so
        -- we'll need to do them manually when automation might have worked,
        -- but this is probably good enough
        ) OR (
            s.shipment_type_id = st.id
            AND st.id = ( SELECT id FROM shipment_type WHERE type = 'Domestic' )
            AND NOT s.real_time_carrier_booking
        )
    ;

COMMIT;
