
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



-- FLEX-208 -- The Nominated Day - New shipping skus for Premier AM
-- New SKUs
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
-- NAP Daytime
(
    '9000211-001',
    'Premier Daytime',
    25.00,
    (select id from currency where currency = 'USD'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    '11:00:00',
    (select id from premier_routing where code = 'D'),
    (select id FROM channel WHERE name = 'NET-A-PORTER.COM')
),
-- NAP Evening
(
    '9000211-002',
    'Premier Evening',
    25.00,
    (select id from currency where currency = 'USD'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    '15:00:00',
    (select id from premier_routing where code = 'E'),
    (select id FROM channel WHERE name = 'NET-A-PORTER.COM')
),
-- MRP Daytime
(
    '9000213-001',
    'Premier Daytime',
    25.00,
    (select id from currency where currency = 'USD'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    '11:00:00',
    (select id from premier_routing where code = 'D'),
    (select id FROM channel WHERE name = 'MRPORTER.COM')
),
-- MRP Evening
(
    '9000213-002',
    'Premier Evening',
    25.00,
    (select id from currency where currency = 'USD'),
    't',
    (select id from shipping_charge_class where class = 'Same Day'),
    '15:00:00',
    (select id from premier_routing where code = 'E'),
    (select id FROM channel WHERE name = 'MRPORTER.COM')
)
;






-- New postcode_shipping_charge mappings
-- NAP
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000211-001'),
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
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000211-002'),
        (select ch.id FROM channel         ch WHERE name = 'NET-A-PORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '900025-002'
    );

-- MRP
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000213-001'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '910025-001'
    );
INSERT INTO postcode_shipping_charge
    (postcode, country_id, shipping_charge_id, channel_id)
    SELECT
        psc.postcode,
        psc.country_id,
        (SELECT sc.id FROM shipping_charge sc WHERE sku = '9000213-002'),
        (select ch.id FROM channel         ch WHERE name = 'MRPORTER.COM')
    FROM postcode_shipping_charge psc
    WHERE shipping_charge_id = (
        SELECT ch.id FROM shipping_charge ch WHERE sku = '910025-001'
    );


COMMIT WORK;

