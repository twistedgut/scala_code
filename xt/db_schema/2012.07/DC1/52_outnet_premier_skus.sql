
BEGIN WORK;



INSERT INTO shipping_charge (
    sku,
    description,
    charge,
    currency_id,
    flat_rate,
    class_id,
    premier_routing_id,
    channel_id,
    latest_nominated_dispatch_daytime
)
VALUES
-- OUT Premier Anytime
(
    '9000214-001',
    'Premier Daytime',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'D'),
    (select id FROM channel WHERE name = 'theOutnet.com'),
    '11:00'
),
(
    '9000214-002',
    'Premier Evening',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'E'),
    (select id FROM channel WHERE name = 'theOutnet.com'),
    '15:00'
)
-- OUT Premier Anytime
;





-- New postcode_shipping_charge mappings
-- OUT Premier Daytime/Evening covers Zone 1..3
-- Premier - Zone 3 900001-001
-- Premier - Zone 2 900002-001
-- Premier - Zone 1 900005-001
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000214-001'),
        (select ch.id FROM channel         ch WHERE name = 'theOutnet.com')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id in (
        SELECT ch.id FROM shipping_charge ch WHERE sku in (
            '900001-001', '900002-001', '900005-001'
        )
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000214-002'),
        (select ch.id FROM channel         ch WHERE name = 'theOutnet.com')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id in (
        SELECT ch.id FROM shipping_charge ch WHERE sku in (
            '900001-001', '900002-001', '900005-001'
        )
    );



COMMIT WORK;

