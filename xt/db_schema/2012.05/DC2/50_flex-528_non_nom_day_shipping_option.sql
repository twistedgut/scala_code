
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
(
    '920003-001',
    'Premier Anytime',
    25.00,
    (select id from currency where currency = 'USD'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'A'),
    (select id FROM channel WHERE name = 'NET-A-PORTER.COM')
),
(
    '920004-001',
    'Premier Anytime',
    25.00,
    (select id from currency where currency = 'USD'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'A'),
    (select id FROM channel WHERE name = 'MRPORTER.COM')
),
(
    '920012-001',
    'Premier Anytime',
    25.00,
    (select id from currency where currency = 'USD'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'A'),
    (select id FROM channel WHERE name = 'theOutnet.com')
)
;



-- New postcode_shipping_charge mappings
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '920003-001'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900025-002'
    );



INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '920004-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900025-002'
    );



INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '920012-001'),
        (select ch.id FROM channel         ch WHERE name = 'theOutnet.com')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900025-002'
    );



COMMIT WORK;

