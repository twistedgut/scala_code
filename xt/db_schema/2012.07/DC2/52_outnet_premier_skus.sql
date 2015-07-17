
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
(
    '9000215-001',
    'Premier Daytime',
    25.00,
    (select id from currency where currency = 'USD'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'D'),
    (select id FROM channel WHERE name = 'theOutnet.com'),
    '11:00'
),
(
    '9000215-002',
    'Premier Evening',
    25.00,
    (select id from currency where currency = 'USD'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    (select id from premier_routing where code = 'E'),
    (select id FROM channel WHERE name = 'theOutnet.com'),
    '15:00'
)
;



-- New postcode_shipping_charge mappings
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000215-001'),
        (select ch.id FROM channel         ch WHERE name = 'theOutnet.com')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900025-002'
    );

INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000215-002'),
        (select ch.id FROM channel         ch WHERE name = 'theOutnet.com')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900025-002'
    );



COMMIT WORK;

