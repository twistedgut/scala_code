
-- FLEX-528
--
-- Create a non-nominated day Premier shipping option
--
-- We require a Premier shipping option in XT which is not nominated
-- day to support changes after selection.



BEGIN WORK;



INSERT INTO shipping_charge (
    sku,
    description,
    charge,
    currency_id,
    flat_rate,
    class_id,
    premier_routing_id,
    channel_id
)
VALUES
-- NAP Premier Anytime
(
    '920001-001',
    'Premier Anytime',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'A'),
    (select id FROM channel WHERE name = 'NET-A-PORTER.COM')
),
-- Maps to: Same postcodes as 900001-001
-- MRP Premier Anytime
(
    '920002-001',
    'Premier Anytime',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'A'),
    (select id FROM channel WHERE name = 'MRPORTER.COM')
),
-- Maps to: Same postcodes as 900001-001
-- TON Premier Anytime
(
    '920011-001',
    'Premier Anytime',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'A'),
    (select id FROM channel WHERE name = 'theOutnet.com')
)
;





-- New postcode_shipping_charge mappings
-- NAP Premier Anytime covers Zone 1..3
-- Premier - Zone 3 900001-001
-- Premier - Zone 2 900002-001
-- Premier - Zone 1 900005-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '920001-001'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id in (
        SELECT ch.id FROM shipping_charge ch WHERE sku in (
            '900001-001', '900002-001', '900005-001'
        )
    );



-- MRP Premier Anytime covers Zone 1..3
-- Premier - Zone 3 910001-001
-- Premier - Zone 2 910002-001
-- Premier - Zone 1 910005-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '920002-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id in (
        SELECT ch.id FROM shipping_charge ch WHERE sku in (
            '910001-001', '910002-001', '910005-001'
        )
    );



-- TON Premier Anytime covers Zone 1..3, (from MRP, as TON doesn't have Premier (yet))
-- Premier - Zone 3 910001-001
-- Premier - Zone 2 910002-001
-- Premier - Zone 1 910005-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '920011-001'),
        (select ch.id FROM channel         ch WHERE name = 'theOutnet.com')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id in (
        SELECT ch.id FROM shipping_charge ch WHERE sku in (
            '910001-001', '910002-001', '910005-001'
        )
    );



COMMIT WORK;

