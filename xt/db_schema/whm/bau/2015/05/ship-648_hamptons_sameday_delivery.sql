-- SHIP-648: Add new shipping details for Hamptons Sameday Delivery
-- for DC2 only

BEGIN;

    -- New shipment class
    INSERT INTO sos.shipment_class(name, api_code)
    VALUES('Premier Evening Hamptons', 'PREMIER_HAMPTONS');


    -- Set processing time for above shipment class
    INSERT INTO sos.processing_time(class_id, processing_time)
    VALUES ((SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_HAMPTONS'), '01:45:00');

    -- Set shipment priority for picking
    INSERT INTO sos.wms_priority(shipment_class_id,wms_priority,wms_bumped_priority,bumped_interval)
    VALUES((SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_HAMPTONS'), 20, 3, '12:00:00');

    -- Shipping Charge
    INSERT INTO shipping_charge(sku, description, charge, currency_id, flat_rate, class_id, channel_id, is_enabled, premier_routing_id, latest_nominated_dispatch_daytime)
    VALUES('904006-001',
           'Premier Evening Hamptons',
           '25.00',
           (SELECT id FROM currency WHERE currency = 'USD'),
           true,
           (SELECT id FROM shipping_charge_class WHERE class='Same Day'),
           (SELECT id FROM channel WHERE name = 'theOutnet.com'),
           false, 4, '13:00:00'),

           ('9000213-003',
           'Premier Evening Hamptons',
           '25.00',
           (SELECT id FROM currency WHERE currency = 'USD'),
           true,
           (SELECT id FROM shipping_charge_class WHERE class='Same Day'),
           (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
           false, 4, '13:00:00'),

           ('9000219-001',
           'Premier Evening Hamptons',
           '25.00',
           (SELECT id FROM currency WHERE currency = 'USD'),
           true,
           (SELECT id FROM shipping_charge_class WHERE class='Same Day'),
           (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
           false, 4, '13:00:00');


    -- Shipping Description
    INSERT INTO shipping.description(name,
                                     public_name,
                                     title,
                                     public_title,
                                     short_delivery_description,
                                     long_delivery_description,
                                     estimated_delivery,
                                     delivery_confirmation,
                                     shipping_charge_id)
    VALUES('Premier',
           'Premier, 5pm-9pm, 7 days a week',
           'Premier, 5pm-9pm, 7 days a week',
           'Premier, 5pm-9pm, 7 days a week',
           'Same-day for orders placed by 12pm',
           '&bull; Delivery for the Hamptons between 5pm-9pm, seven days a week<br />&bull; Place your order by 12pm for same-day service<br />&bull; Allocated 2 hour delivery window<br />&bull; Select a nominated date for delivery up to seven days in advance',
           'Delivery between 5pm-9pm',
           'Our Premier service will contact you on the day of dispatch with a two-hour delivery window.',
           (SELECT id FROM shipping_charge WHERE sku = '904006-001' AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com'))),

           ('Premier',
           'Premier, 5pm-9pm, 7 days a week',
           'Premier, 5pm-9pm, 7 days a week',
           'Premier, 5pm-9pm, 7 days a week',
           'Same-day for orders placed by 12pm',
           '&bull; Delivery for the Hamptons between 5pm-9pm, seven days a week<br />&bull; Place your order by 12pm for same-day service<br />&bull; Allocated 2 hour delivery window<br />&bull; Select a nominated date for delivery up to seven days in advance',
           'Delivery between 5pm-9pm',
           'Our Premier service will contact you on the day of dispatch with a two-hour delivery window.',
           (SELECT id FROM shipping_charge WHERE sku = '9000213-003' AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM'))),

           ('Premier',
           'Premier, 5pm-9pm, 7 days a week',
           'Premier, 5pm-9pm, 7 days a week',
           'Premier, 5pm-9pm, 7 days a week',
           'Same-day for orders placed by 12pm',
           '&bull; Delivery for the Hamptons between 5pm-9pm, seven days a week<br />&bull; Place your order by 12pm for same-day service<br />&bull; Allocated 2 hour delivery window<br />&bull; Select a nominated date for delivery up to seven days in advance',
           'Delivery between 5pm-9pm',
           'Our Premier service will contact you on the day of dispatch with a two-hour delivery window.',
           (SELECT id FROM shipping_charge WHERE sku = '9000219-001' AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')));


    -- New truck departure
    INSERT INTO sos.truck_departure (
        begin_date,
        carrier_id,
        week_day_id,
        departure_time
    ) VALUES
    (
        '01-06-2015',
        (SELECT id FROM sos.carrier WHERE code = 'NAP'),
        (SELECT id FROM sos.week_day WHERE name = 'Monday'),
        '13:45:00'
    ),
    (
        '01-06-2015',
        (SELECT id FROM sos.carrier WHERE code = 'NAP'),
        (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
        '13:45:00'
    ),
    (
        '01-06-2015',
        (SELECT id FROM sos.carrier WHERE code = 'NAP'),
        (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
        '13:45:00'
    ),
    (
        '01-06-2015',
        (SELECT id FROM sos.carrier WHERE code = 'NAP'),
        (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
        '13:45:00'
    ),
    (
        '01-06-2015',
        (SELECT id FROM sos.carrier WHERE code = 'NAP'),
        (SELECT id FROM sos.week_day WHERE name = 'Friday'),
        '13:45:00'
    ),
    (
        '01-06-2015',
        (SELECT id FROM sos.carrier WHERE code = 'NAP'),
        (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
        '13:45:00'
    ),
    (
        '01-06-2015',
        (SELECT id FROM sos.carrier WHERE code = 'NAP'),
        (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
        '13:45:00'
    );


    INSERT INTO sos.truck_departure__shipment_class (truck_departure_id, shipment_class_id) VALUES
        ((SELECT id FROM sos.truck_departure
            WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
            AND week_day_id = (SELECT id FROM sos.week_day WHERE name = 'Monday')
            AND begin_date = '01-06-2015'),
        (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_HAMPTONS')),

        ((SELECT id FROM sos.truck_departure
            WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
            AND week_day_id = (SELECT id FROM sos.week_day WHERE name = 'Tuesday')
            AND begin_date = '01-06-2015'),
        (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_HAMPTONS')),

        ((SELECT id FROM sos.truck_departure
            WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
            AND week_day_id = (SELECT id FROM sos.week_day WHERE name = 'Wednesday')
            AND begin_date = '01-06-2015'),
        (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_HAMPTONS')),

        ((SELECT id FROM sos.truck_departure
            WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
            AND week_day_id = (SELECT id FROM sos.week_day WHERE name = 'Thursday')
            AND begin_date = '01-06-2015'),
        (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_HAMPTONS')),

        ((SELECT id FROM sos.truck_departure
            WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
            AND week_day_id = (SELECT id FROM sos.week_day WHERE name = 'Friday')
            AND begin_date = '01-06-2015'),
        (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_HAMPTONS')),

        ((SELECT id FROM sos.truck_departure
            WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
            AND week_day_id = (SELECT id FROM sos.week_day WHERE name = 'Saturday')
            AND begin_date = '01-06-2015'),
        (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_HAMPTONS')),

        ((SELECT id FROM sos.truck_departure
            WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
            AND week_day_id = (SELECT id FROM sos.week_day WHERE name = 'Sunday')
            AND begin_date = '01-06-2015'),
        (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_HAMPTONS'));


    -- Shipping charges for TON postcodes
    INSERT INTO postcode_shipping_charge
        (postcode, country_id, shipping_charge_id, channel_id)
    VALUES(
        '11930',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11932',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11937',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11954',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11963',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11962',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11968',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11969',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11975',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11976',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    ),
    (
        '11977',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '904006-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'theOutnet.com')
    );


    -- Shipping charges for NAP postcodes
    INSERT INTO postcode_shipping_charge
        (postcode, country_id, shipping_charge_id, channel_id)
    VALUES(
        '11930',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11932',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11937',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11954',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11963',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11962',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11968',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11969',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11975',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11976',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    ),
    (
        '11977',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000219-001'
            AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
    );


    -- Shipping charges for MRP postcodes
    INSERT INTO postcode_shipping_charge
        (postcode, country_id, shipping_charge_id, channel_id)
    VALUES(
        '11930',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11932',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11937',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11954',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11963',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11962',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11968',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11969',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11975',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11976',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    ),
    (
        '11977',
        (SELECT id FROM country WHERE country = 'United States'),
        (SELECT id FROM shipping_charge WHERE sku = '9000213-003'
            AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
            AND class_id   = (SELECT id FROM shipping_charge_class WHERE class='Same Day')),
        (SELECT id FROM channel WHERE name = 'MRPORTER.COM')
    );

    -- Need the 'Premier Evening Hamptons' shipping_class to override the 'theOutnet.com, Full Sale, Mixed Sale' when calculating the SLA

    INSERT INTO sos.processing_time_override (major_id,minor_id)
        VALUES((select id from sos.processing_time where class_id =
                    (select id from sos.shipment_class where name = 'Premier Evening Hamptons')),
               (select id from sos.processing_time where channel_id =
                    (select id from sos.channel where name = 'theOutnet.com'))),

        ((select id from sos.processing_time where class_id =
                    (select id from sos.shipment_class where name = 'Premier Evening Hamptons')),
               (select id from sos.processing_time where class_attribute_id =
                    (select id from sos.shipment_class_attribute where name = 'Full Sale'))),

        ((select id from sos.processing_time where class_id =
                    (select id from sos.shipment_class where name = 'Premier Evening Hamptons')),
               (select id from sos.processing_time where class_attribute_id =
                    (select id from sos.shipment_class_attribute where name = 'Mixed Sale')));

COMMIT;
