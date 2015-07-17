BEGIN;

    -- Add new 'Next Business Day' SKUs for Luxembourg, Malta, Hungary, Slovenia, Sweden, Slovakia,
    --  Czech Republic, Austria, Spain, Finland
    -- For both NAP and MRP channels
    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000429-009',
            'Luxembourg Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            TRUE,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Luxembourg'),
            (SELECT id FROM shipping_charge WHERE sku = '9000429-009' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000429-009'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000429-009'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-009',
            'Luxembourg Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Luxembourg'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-009' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000430-010',
            'Malta Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Malta'),
            (SELECT id FROM shipping_charge WHERE sku = '9000430-010' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000430-010'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000430-010'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-010',
            'Malta Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Malta'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-010' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000431-011',
            'Hungary Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Hungary'),
            (SELECT id FROM shipping_charge WHERE sku = '9000431-011' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000431-011'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000431-011'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-011',
            'Hungary Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Hungary'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-011' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000432-012',
            'Slovenia Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Slovenia'),
            (SELECT id FROM shipping_charge WHERE sku = '9000432-012' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000432-012'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000432-012'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-012',
            'Slovenia Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Slovenia'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-012' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000433-013',
            'Sweden Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Sweden'),
            (SELECT id FROM shipping_charge WHERE sku = '9000433-013' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000433-013'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000433-013'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-013',
            'Sweden Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Sweden'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-013' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000434-014',
            'Slovakia Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Slovakia'),
            (SELECT id FROM shipping_charge WHERE sku = '9000434-014' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000434-014'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000434-014'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-014',
            'Slovakia Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Slovakia'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-014' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000435-015',
            'Czech Republic Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Czech Republic'),
            (SELECT id FROM shipping_charge WHERE sku = '9000435-015' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000435-015'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000435-015'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-015',
            'Czech Republic Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Czech Republic'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-015' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000436-016',
            'Austria Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Austria'),
            (SELECT id FROM shipping_charge WHERE sku = '9000436-016' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000436-016'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000436-016'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-016',
            'Austria Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Austria'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-016' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000437-017',
            'Spain Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Spain'),
            (SELECT id FROM shipping_charge WHERE sku = '9000437-017' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000437-017'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000437-017'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-017',
            'Spain Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Spain'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-017' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );


    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '9000438-018',
            'Finland Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            FALSE
        );
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Finland'),
            (SELECT id FROM shipping_charge WHERE sku = '9000438-018' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );
    INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000438-018'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000438-018'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        )
    ;

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled)
        VALUES (
            '910003-018',
            'Finland Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            FALSE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'Finland'),
            (SELECT id FROM shipping_charge WHERE sku = '910003-018' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

COMMIT;