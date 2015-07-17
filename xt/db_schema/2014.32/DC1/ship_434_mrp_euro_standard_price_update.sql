BEGIN;

    -- MrP Euro-Standard price update (DC1 only)

    -- For the UK...
    UPDATE shipping_charge
        SET charge = '5.08'
        WHERE sku IN (
            '9010203-001',
            '9010204-001'
        )
    ;

    -- For the rest of europe...
    UPDATE shipping.region_charge
        SET charge = '8'
        WHERE shipping_charge_id IN (
            SELECT id
            FROM shipping_charge
            WHERE sku IN (
                '9010203-001',
                '9010204-001'
            )
        )
        AND region_id IN (
            SELECT id
            FROM region
            WHERE region IN (
                'Europe',
                'Europe Other'
            )
        )
    ;

COMMIT;