BEGIN;

-- FLEX-179
-- Add the same International Road shipping charges and accounts for
-- NAP and MRP as OUT already has.

-- Remove earlier ones with the wrong description and cost
DELETE FROM shipping_charge WHERE sku IN ('9000203-001', '9010203-001');

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
    'NAP - International Road, 2-3 days',
    10.95,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Ground')
),
(
    '9000204-001',
    'NAP - International Road, 4-5 days',
    10.95,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Ground')
),
-- MRP INTL
(
    '9010203-001',
    'MRP - International Road, 2-3 days',
    10.95,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Ground')
),
(
    '9010204-001',
    'MRP - International Road, 4-5 days',
    10.95,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Ground')
)
;

COMMIT;
