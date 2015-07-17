-- Add a new shipping SKU for next day France for NAP and MRP

BEGIN;
     -- Add next day France entries to the shipping_charge table
    INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
        VALUES
        (
            '9000420-008',
            'France Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        ),
        (
            '9000421-008',
            'France Next Business Day',
            20.00,
            (SELECT id FROM currency WHERE currency='GBP'),
            true,
            (SELECT id FROM shipping_charge_class WHERE class='Air'),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    -- Add entries to the country_shipping_charge table
    INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
        VALUES
        (
            (SELECT id FROM country WHERE country = 'France'),
            (SELECT id FROM shipping_charge WHERE sku = '9000420-008' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')),
            (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
        ),
        (
            (SELECT id FROM country WHERE country = 'France'),
            (SELECT id FROM shipping_charge WHERE sku = '9000421-008' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')),
            (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
        );

    -- Add shipping.description entry for NAP
    INSERT INTO shipping.description
        (name, public_name, title, public_title, short_delivery_description, long_delivery_description, estimated_delivery, delivery_confirmation, shipping_charge_id)
        VALUES (
            'France Next Business Day',
            'Next Business Day',
            'Next Business Day',
            'Next Business Day',
            'For orders placed Mon-Fri by 4 PM',
            'Next Business Day orders placed after 4pm on Friday will be delivered on Tuesday.',
            'Delivery: next business day, Mon-Fri, 9am-5pm',
            'You will receive an email confirming the dispatch of your order and your Air Waybill number.',
            (SELECT id FROM shipping_charge WHERE sku = '9000420-008')
        );
COMMIT;
