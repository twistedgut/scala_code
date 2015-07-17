BEGIN;

    -- Add new 'Next Day' SKUs for Belgium, Denmark, Germany, Ireland, Netherlands, Switzerland
    -- For both NAP and MRP channels
    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000420-002',
            'Belgium Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Belgium'),
            (SELECT id FROM shipping_charge WHERE sku = '9000420-002' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000421-002',
            'Belgium Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Belgium'),
            (SELECT id FROM shipping_charge WHERE sku = '9000421-002' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );




    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000420-003',
            'Denmark Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Denmark'),
            (SELECT id FROM shipping_charge WHERE sku = '9000420-003' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000421-003',
            'Denmark Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Denmark'),
            (SELECT id FROM shipping_charge WHERE sku = '9000421-003' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );





    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000420-004',
            'Germany Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Germany'),
            (SELECT id FROM shipping_charge WHERE sku = '9000420-004' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000421-004',
            'Germany Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Germany'),
            (SELECT id FROM shipping_charge WHERE sku = '9000421-004' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );





    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000420-005',
            'Ireland Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Ireland'),
            (SELECT id FROM shipping_charge WHERE sku = '9000420-005' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000421-005',
            'Ireland Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Ireland'),
            (SELECT id FROM shipping_charge WHERE sku = '9000421-005' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );





    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000420-006',
            'Netherlands Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Netherlands'),
            (SELECT id FROM shipping_charge WHERE sku = '9000420-006' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000421-006',
            'Netherlands Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Netherlands'),
            (SELECT id FROM shipping_charge WHERE sku = '9000421-006' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );




    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000420-007',
            'Switzerland Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Switzerland'),
            (SELECT id FROM shipping_charge WHERE sku = '9000420-007' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES (
            '9000421-007',
            'Switzerland Next Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Switzerland'),
            (SELECT id FROM shipping_charge WHERE sku = '9000421-007' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

COMMIT;