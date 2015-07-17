
-- FLEX-31
--
-- Create a Courier shipping option (special Premier one)
--
-- This is to create special case Premier shipments just outside the
-- regular Premier zone using a courier service.



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
-- NAP Courier Special Delivery
(
    '920013-001',
    'Courier Special Delivery',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'A'),
    (select id FROM channel WHERE name = 'NET-A-PORTER.COM')
),
-- MRP Courier Special Delivery
(
    '920014-001',
    'Courier Special Delivery',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'A'),
    (select id FROM channel WHERE name = 'MRPORTER.COM')
),
-- OUT Courier Special Delivery
(
    '920015-001',
    'Courier Special Delivery',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'A'),
    (select id FROM channel WHERE name = 'theOutnet.com')
)
;





-- New country_shipping_charge mappings
-- NAP Courier Special Delivery covers the UK
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        c.id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '920013-001'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM country c
    WHERE code = 'GB'
;



-- MRP Courier Special Delivery covers the UK
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        c.id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '920014-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM country c
    WHERE code = 'GB'
    ;



-- OUT Courier Special Delivery covers the UK
INSERT INTO country_shipping_charge
    (country_id, shipping_charge_id, channel_id)
    SELECT
        c.id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '920015-001'),
        (select ch.id FROM channel         ch WHERE name = 'theOutnet.com')
    FROM country c
    WHERE code = 'GB'
    ;



COMMIT WORK;

