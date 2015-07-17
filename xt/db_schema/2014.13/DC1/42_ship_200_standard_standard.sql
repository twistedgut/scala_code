BEGIN;

    -- Add new 'standard' shipping SKU for UK domestic
    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_slow)
        VALUES (
            '9000420-001',
            'UK Standard',
            4.17, -- TODO: Need actual price
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
            TRUE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'United Kingdom'),
            (SELECT id FROM shipping_charge WHERE sku = '9000420-001' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        );

    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_slow)
        VALUES (
            '9000421-001',
            'UK Standard',
            4.17,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
            TRUE
        );

    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES (
            (SELECT id FROM country WHERE country = 'United Kingdom'),
            (SELECT id FROM shipping_charge WHERE sku = '9000421-001' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    -- Add the processing time for DC1 'Slow' shipments
    INSERT INTO sos.processing_time (class_attribute_id, processing_time)
        VALUES(
            (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Slow'),
            '39:00:00'
        );

COMMIT;