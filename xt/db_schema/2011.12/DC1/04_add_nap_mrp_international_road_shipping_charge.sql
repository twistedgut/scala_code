BEGIN;

-- FLEX-179
-- Add the same International Road shipping charges and accounts for
-- NAP and MRP as OUT already has.

SELECT setval('shipping_account_id_seq', (
    SELECT max(id) FROM shipping_account)
);
INSERT INTO shipping_account (
    name,
    account_number,
    carrier_id,
    channel_id,
    return_cutoff_days
) VALUES 
    (
        'International Road',
        '185329286',
        (SELECT id FROM carrier WHERE name = 'DHL Express'),
        (SELECT id FROM channel WHERE web_name = 'NAP-INTL'),
        16
    ),
    (
        'International Road',
        '185329301',
        (SELECT id FROM carrier WHERE name = 'DHL Express'),
        (SELECT id FROM channel WHERE web_name = 'MRP-INTL'),
        16
    )
;


SELECT setval('shipping_charge_id_seq', (
    SELECT max(id) FROM shipping_charge)
);
INSERT INTO shipping_charge (
    sku,
    description,
    charge,
    currency_id,
    flat_rate,
    class_id
)
VALUES
-- NAP INTL
(
    '9000203-001',
    'NAP - International Road',
    5.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Ground')
),
-- MRP INTL
(
    '9010203-001',
    'MRP - International Road',
    5.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Ground')
);


COMMIT;
