

BEGIN;

-- Add shipping_charges that are present in the web site, but missing
-- in XT


-- SKU: 9010206-001
-- Name: Hawaii 3-5 Business Days
-- Price: 0.00
insert into shipping_charge
    (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
    values (
        '9010206-001',
        'Hawaii 3-5 Business Days',
        0.00,
        (select id from currency where currency = 'USD'),
        't',
        (select id from shipping_charge_class where class = 'Ground'),
        (select id from channel where name = 'MRPORTER.COM')
    )
;
insert into state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    values (
        'HI',
        (select id from country where country = 'United States'),
        (select currval('shipping_charge_id_seq'::regclass)),
        (select id from channel where name = 'MRPORTER.COM')
    )
;



-- SKU: 9010207-001
-- Name: Minnesota 3-5 Business Days
-- Price: 0.00
insert into shipping_charge
    (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
    values (
        '9010207-001',
        'Minnesota 3-5 Business Days',
        0.00,
        (select id from currency where currency = 'USD'),
        't',
        (select id from shipping_charge_class where class = 'Ground'),
        (select id from channel where name = 'MRPORTER.COM')
    )
;
insert into state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    values (
        'MN',
        (select id from country where country = 'United States'),
        (select currval('shipping_charge_id_seq'::regclass)),
        (select id from channel where name = 'MRPORTER.COM')
    )
;


-- SKU: 9010208-001
-- Name: Missouri 3-5 Business Days
-- Price: 0.00
insert into shipping_charge
    (sku, description, charge, currency_id, flat_rate, class_id, channel_id)
    values (
        '9010208-001',
        'Missouri 3-5 Business Days',
        0.00,
        (select id from currency where currency = 'USD'),
        't',
        (select id from shipping_charge_class where class = 'Ground'),
        (select id from channel where name = 'MRPORTER.COM')
    )
;
insert into state_shipping_charge
    (state, country_id, shipping_charge_id, channel_id)
    values (
        'MO',
        (select id from country where country = 'United States'),
        (select currval('shipping_charge_id_seq'::regclass)),
        (select id from channel where name = 'MRPORTER.COM')
    )
;


COMMIT;
