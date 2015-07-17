BEGIN;

    -- Add shipping_class_ids to shipping_account
    UPDATE shipping_account
        SET shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'Unknown')
        WHERE name = 'Unknown';
    UPDATE shipping_account
        SET shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'Domestic')
        WHERE name = 'Domestic';
    UPDATE shipping_account
        SET shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'International')
        WHERE name = 'International';
    UPDATE shipping_account
        SET shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'International Road')
        WHERE name = 'International Road';
    UPDATE shipping_account
        SET shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'FTBC')
        WHERE name = 'FTBC';

    INSERT INTO ups_service (code, description, shipping_charge_class_id) VALUES
        ('01', 'UPS Next Day Air', (SELECT id FROM shipping_charge_class WHERE class = 'Air')),
        ('02', 'UPS Second Day Air', (SELECT id FROM shipping_charge_class WHERE class = 'Air')),
        ('03', 'UPS Ground', (SELECT id FROM shipping_charge_class WHERE class = 'Ground') ),
        ('12', 'UPS Three Day Select', (SELECT id FROM shipping_charge_class WHERE class = 'Air')),
        ('13', 'UPS Next Day Air Saver', (SELECT id FROM shipping_charge_class WHERE class = 'Air')),
        ('65', 'UPS Saver', (SELECT id FROM shipping_charge_class WHERE class = 'Ground')),
        ('65', 'UPS Saver', (SELECT id FROM shipping_charge_class WHERE class = 'Air'));

    -- These are the services that are available by default
    INSERT INTO ups_service_availability (ups_service_id, shipping_class_id, shipping_direction_id,
            shipping_charge_id, rank) VALUES
        (
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            NULL,
            1
        ),
        (
            (SELECT id FROM ups_service WHERE code = '13' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            NULL,
            2
        ),
        (
            (SELECT id FROM ups_service WHERE code = '01' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            NULL,
            3
        ),
        (
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            NULL,
            1
        ),
        (
            (SELECT id FROM ups_service WHERE code = '02' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            NULL,
            2
        ),
        (
            (SELECT id FROM ups_service WHERE code = '65'
                AND shipping_charge_class_id  = (SELECT id FROM shipping_charge_class WHERE class = 'Ground') ),
            (SELECT id FROM shipping_class WHERE name = 'International' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            NULL,
            1
        ),
        (
            (SELECT id FROM ups_service WHERE code = '65'
                AND shipping_charge_class_id  = (SELECT id FROM shipping_charge_class WHERE class = 'Air') ),
            (SELECT id FROM shipping_class WHERE name = 'International' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            NULL,
            1
        ),
        (
            (SELECT id FROM ups_service WHERE code = '65'
                AND shipping_charge_class_id  = (SELECT id FROM shipping_charge_class WHERE class = 'Ground') ),
            (SELECT id FROM shipping_class WHERE name = 'International' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            NULL,
            1
        ),
        (
            (SELECT id FROM ups_service WHERE code = '65'
                AND shipping_charge_class_id  = (SELECT id FROM shipping_charge_class WHERE class = 'Air') ),
            (SELECT id FROM shipping_class WHERE name = 'International' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            NULL,
            1
        ),

    -- These services are only available to specific shipping_charges
    -- (Some american states can only use '3 Day Air' and some '2 Day Air' and only ground
    -- for returns)
        (   -- NAP, Mississippi
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900077-002' ),
            1
        ),
        (   -- MrP, Mississippi
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910077-001' ),
            1
        ),
        (   -- MrP, Louisiana
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910067-001' ),
            1
        ),
        (   -- NAP, Louisiana
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900067-002' ),
            1
        ),
        (   -- NAP, Minnesota
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900073-002' ),
            1
        ),
        (   -- MrP, Minnesota
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010207-001' ),
            1
        ),
        (   -- NAP, North Dakota
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900083-002' ),
            1
        ),
        (   -- MrP, North Dakota
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910083-001' ),
            1
        ),
        (   -- NAP, South Dakota
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000101-002' ),
            1
        ),
        (   -- MrP, South Dakota
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010101-001' ),
            1
        ),
        (   --NAP, Nebraska
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900085-002' ),
            1
        ),
        (   -- MrP, Nebraska
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910085-001' ),
            1
        ),
        (   -- MrP, Oklahoma
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910095-001' ),
            1
        ),
        (   -- NAP, Oklahoma
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900095-002' ),
            1
        ),
        (   -- MrP, Texas
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010105-001' ),
            1
        ),
        (   -- NAP, Texas
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000105-002' ),
            1
        ),
        (   -- NAP, Montana
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900079-002' ),
            1
        ),
        (   -- MrP, Montana
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910079-001' ),
            1
        ),
        (   -- NAP, Wyoming
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000117-002' ),
            1
        ),
        (   -- MrP, Wyoming
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010117-001' ),
            1
        ),
        (   -- MrP, Colorado
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910047-001' ),
            1
        ),
        (   -- NAP, Colorado
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900047-002' ),
            1
        ),
        (   -- MrP, New Mexico
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910089-001' ),
            1
        ),
        (   -- NAP, New Mexico
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900089-002' ),
            1
        ),
        (   -- MrP, Idaho
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910057-001' ),
            1
        ),
        (   -- NAP, Idaho
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900057-002' ),
            1
        ),
        (   -- MrP, Utah
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010107-001' ),
            1
        ),
        (   -- NAP, Utah
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000107-002' ),
            1
        ),
        (   -- MrP, Arizona
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910043-001' ),
            1
        ),
        (   -- NAP, Arizona
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900043-002' ),
            1
        ),
        (   -- MrP, Washington
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010111-001' ),
            1
        ),
        (   -- NAP, Washington
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000111-002' ),
            1
        ),
        (   -- NAP, Oregon
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900097-002' ),
            1
        ),
        (   -- MrP, Oregon
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910097-001' ),
            1
        ),
        (   -- MrP, Nevada
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910091-001' ),
            1
        ),
        (   -- NAP, Nevada
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900091-002' ),
            1
        ),
        (   -- MrP, California
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '910045-001' ),
            1
        ),
        (   -- NAP, California
            (SELECT id FROM ups_service WHERE code = '12' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900045-002' ),
            1
        ),

        -- Returns for these states are by ground
        (   -- NAP, Mississippi
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900077-002' ),
            1
        ),
        (   -- MrP, Mississippi
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910077-001' ),
            1
        ),
        (   -- MrP, Louisiana
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910067-001' ),
            1
        ),
        (   -- NAP, Louisiana
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900067-002' ),
            1
        ),
        (   -- NAP, Minnesota
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900073-002' ),
            1
        ),
        (   -- MrP, Minnesota
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010207-001' ),
            1
        ),
        (   -- NAP, North Dakota
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900083-002' ),
            1
        ),
        (   -- MrP, North Dakota
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910083-001' ),
            1
        ),
        (   -- NAP, South Dakota
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000101-002' ),
            1
        ),
        (   -- MrP, South Dakota
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010101-001' ),
            1
        ),
        (   -- NAP, Nebraska
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900085-002' ),
            1
        ),
        (   -- MrP, Nebraska
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910085-001' ),
            1
        ),
        (   -- MrP, Oklahoma
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910095-001' ),
            1
        ),
        (   -- NAP, Oklahoma
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900095-002' ),
            1
        ),
        (   -- MrP, Texas
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010105-001' ),
            1
        ),
        (   -- NAP, Texas
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000105-002' ),
            1
        ),
        (   -- NAP, Montana
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900079-002' ),
            1
        ),
        (   -- MrP, Montana
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910079-001' ),
            1
        ),
        (   -- NAP, Wyoming
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000117-002' ),
            1
        ),
        (   -- MrP, Wyoming
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010117-001' ),
            1
        ),
        (   -- MrP, Colorado
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910047-001' ),
            1
        ),
        (   -- NAP, Colorado
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900047-002' ),
            1
        ),
        (   -- MrP, New Mexico
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910089-001' ),
            1
        ),
        (   -- NAP, New Mexico
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900089-002' ),
            1
        ),
        (   -- MrP, Idaho
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910057-001' ),
            1
        ),
        (   -- NAP, Idaho
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900057-002' ),
            1
        ),
        (   -- MrP, Utah
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010107-001' ),
            1
        ),
        (   -- NAP, Utah
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000107-002' ),
            1
        ),
        (   -- MrP, Arizona
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910043-001' ),
            1
        ),
        (   -- NAP, Arizona
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900043-002' ),
            1
        ),
        (   -- MrP, Washington
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010111-001' ),
            1
        ),
        (   -- NAP, Washington
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000111-002' ),
            1
        ),
        (   -- NAP, Oregon
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900097-002' ),
            1
        ),
        (   -- MrP, Oregon
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910097-001' ),
            1
        ),
        (   -- MrP, Nevada
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910091-001' ),
            1
        ),
        (   -- NAP, Nevada
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900091-002' ),
            1
        ),
        (   -- MrP, California
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '910045-001' ),
            1
        ),
        (   -- NAP, California
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900045-002' ),
            1
        ),

        -- Some states require faster shipping
        (   -- NAP, Alaska
            (SELECT id FROM ups_service WHERE code = '02' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900037-002' ),
            1
        ),
        (   -- NAP, Alaska (old 'Ground' sku)
            (SELECT id FROM ups_service WHERE code = '02' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000205-001' ),
            1
        ),
        (   -- MrP, Alaska (old 'Ground' sku)
            (SELECT id FROM ups_service WHERE code = '02' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010205-001' ),
            1
        ),
        (   -- MrP, Hawaii
            (SELECT id FROM ups_service WHERE code = '02' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010206-001' ),
            1
        ),
        (   -- NAP, Hawaii
            (SELECT id FROM ups_service WHERE code = '02' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '900053-002' ),
            1
        ),
        (   -- NAP, Hawaii (old 'Ground' sku)
            (SELECT id FROM ups_service WHERE code = '02' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Outgoing' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000206-001' ),
            1
        ),

        -- Returns by the same method
        (   -- NAP, Alaska
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900037-002' ),
            1
        ),
        (   -- NAP, Alaska (old 'Ground' sku)
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000205-001' ),
            1
        ),
        (   -- MrP, Alaska (old 'Ground' sku)
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010205-001' ),
            1
        ),
        (   -- MrP, Hawaii
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9010206-001' ),
            1
        ),
        (   -- NAP, Hawaii
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '900053-002' ),
            1
        ),
        (   -- NAP, Hawaii (old 'Ground' sku)
            (SELECT id FROM ups_service WHERE code = '03' ),
            (SELECT id FROM shipping_class WHERE name = 'Domestic' ),
            (SELECT id FROM shipping_direction WHERE name = 'Return' ),
            (SELECT id FROM shipping_charge WHERE sku = '9000206-001' ),
            1
        )
        ;

-- Rename shipping skus and change charge class to air
UPDATE shipping_charge
    SET class_id = (SELECT id FROM shipping_charge_class WHERE class = 'Air')
    WHERE id IN (
        SELECT sc.id FROM shipping_charge sc
            LEFT JOIN ups_service_availability usa ON sc.id = usa.shipping_charge_id
            JOIN ups_service us ON usa.ups_service_id = us.id
            JOIN shipping_direction sd ON usa.shipping_direction_id = sd.id
            WHERE sd.name = 'Outgoing' AND us.code = '12'
    );
UPDATE shipping_charge
    SET description = regexp_replace(description, '(.+)3-5 Business Days', '\\13 day Air')
    WHERE id IN (
        SELECT sc.id FROM shipping_charge sc
            LEFT JOIN ups_service_availability usa ON sc.id = usa.shipping_charge_id
            JOIN ups_service us ON usa.ups_service_id = us.id
            JOIN shipping_direction sd ON usa.shipping_direction_id = sd.id
            WHERE sd.name = 'Outgoing' AND us.code = '12'
    );

UPDATE shipping_charge
    SET class_id = (SELECT id FROM shipping_charge_class WHERE class = 'Air')
    WHERE id IN (
        SELECT sc.id FROM shipping_charge sc
            LEFT JOIN ups_service_availability usa ON sc.id = usa.shipping_charge_id
            JOIN ups_service us ON usa.ups_service_id = us.id
            JOIN shipping_direction sd ON usa.shipping_direction_id = sd.id
            WHERE sd.name = 'Outgoing' AND us.code = '02'
    );
UPDATE shipping_charge
    SET description = regexp_replace(description, '(.+)3-5 Business Days', '\\12nd Day')
    WHERE id IN (
        SELECT sc.id FROM shipping_charge sc
            LEFT JOIN ups_service_availability usa ON sc.id = usa.shipping_charge_id
            JOIN ups_service us ON usa.ups_service_id = us.id
            JOIN shipping_direction sd ON usa.shipping_direction_id = sd.id
            WHERE sd.name = 'Outgoing' AND us.code = '02'
    );

UPDATE shipping_charge
    SET description = regexp_replace(description, '(.+)Ground', '\\12nd Day')
    WHERE id IN (
        SELECT sc.id FROM shipping_charge sc
            LEFT JOIN ups_service_availability usa ON sc.id = usa.shipping_charge_id
            JOIN ups_service us ON usa.ups_service_id = us.id
            JOIN shipping_direction sd ON usa.shipping_direction_id = sd.id
            WHERE sd.name = 'Outgoing' AND us.code = '02'
    );

COMMIT;
