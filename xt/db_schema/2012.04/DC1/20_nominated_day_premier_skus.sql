
BEGIN WORK;

-- FLEX-358
-- Add column shipping_charge.latest_nominated_dispatch_daytime, and
-- values
ALTER TABLE shipping_charge
    -- If the Shipping Charge is for Nominated Day, the latest time of
    -- day when the Shipment must be dispatched to reach the Customer
    -- at the correct nominated_delivery_date
    ADD COLUMN latest_nominated_dispatch_daytime TIME NULL
;

-- FLEX-250
-- Add values to the premier_routing table and a FK from
-- shipping_charge
INSERT INTO premier_routing (id, code, description) VALUES
(3, 'D', 'Daytime, 10:00-16:00'),
(4, 'E', 'Evening, 18:00-21:00')
;

ALTER TABLE shipping_charge
    ADD COLUMN premier_routing_id INTEGER NULL,
    ADD CONSTRAINT shipping_charge_routing_id_fkey
        FOREIGN KEY (premier_routing_id)
        REFERENCES premier_routing (id)
;



-- FLEX-208 -- The Nominated Day - New shipping skus for Premier INTL
INSERT INTO shipping_charge (
    sku,
    description,
    charge,
    currency_id,
    flat_rate,
    class_id,
    latest_nominated_dispatch_daytime,
    premier_routing_id,
    channel_id
)
VALUES
-- NAP Premier Daytime/Evening
(
    '9000210-001',
    'Premier Daytime',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    '11:00:00',
    (select id from premier_routing where code = 'D'),
    (select id FROM channel WHERE name = 'NET-A-PORTER.COM')
),
-- -- NAP --
-- NAP 900001-002
-- Maps to: Same postcodes as 900001-001
(
    '9000210-002',
    'Premier Evening',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    '15:00:00',
    (select id from premier_routing where code = 'E'),
    (select id FROM channel WHERE name = 'NET-A-PORTER.COM')
),
-- MRP Premier Daytime/Evening
(
    '9000212-001',
    'Premier Daytime',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    '11:00:00',
    (select id from premier_routing where code = 'D'),
    (select id FROM channel WHERE name = 'MRPORTER.COM')
),
-- -- MRP --
-- MRP 910001-002
-- Maps to: Same postcodes as 910001-001
(
    '9000212-002',
    'Premier Evening',
    10.00,
    (select id from currency where currency = 'GBP'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    '15:00:00',
    (select id from premier_routing where code = 'E'),
    (select id FROM channel WHERE name = 'MRPORTER.COM')
)
;




-- New postcode_shipping_charge mappings
-- NAP Premier Nominated Daytime/Evening covers Zone 1..3
-- Premier - Zone 3 900001-001
-- Premier - Zone 2 900002-001
-- Premier - Zone 1 900005-001
-- Daytime
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000210-001'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900001-001'
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000210-001'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900002-001'
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000210-001'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900005-001'
    );
-- Evening
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000210-002'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900001-001'
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000210-002'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900002-001'
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000210-002'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900005-001'
    );


-- MRP Premier Nominated Day covers Zone 1..3
-- Premier - Zone 3 910001-001
-- Premier - Zone 2 910002-001
-- Premier - Zone 1 910005-001
-- Daytime
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000212-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '910001-001'
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000212-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '910002-001'
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000212-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '910005-001'
    );
-- Evening
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000210-002'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '910001-001'
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000210-002'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '910002-001'
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000210-002'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '910005-001'
    );


COMMIT WORK;

