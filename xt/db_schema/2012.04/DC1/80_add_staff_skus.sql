BEGIN;

INSERT INTO shipping_charge (
    sku, description, charge, currency_id, flat_rate, class_id, channel_id, premier_routing_id
) VALUES (
    '920005-001','Internal Staff Order', 0.00,
    (SELECT id FROM currency WHERE currency = 'GBP'),
    TRUE,
    (SELECT id FROM shipping_charge_class WHERE class = 'Same Day'),
    (SELECT id FROM channel WHERE web_name = 'NAP-INTL'),
    0
);

INSERT INTO shipping_charge (
    sku, description, charge, currency_id, flat_rate, class_id, channel_id, premier_routing_id
) VALUES (
    '920006-001','Internal Staff Order', 0.00,
    (SELECT id FROM currency WHERE currency = 'GBP'),
    TRUE,
    (SELECT id FROM shipping_charge_class WHERE class = 'Same Day'),
    (SELECT id FROM channel WHERE web_name = 'MRP-INTL'),
    0
);

INSERT INTO shipping_charge (
    sku, description, charge, currency_id, flat_rate, class_id, channel_id, premier_routing_id
) VALUES (
    '920007-001','Internal Staff Order', 0.00,
    (SELECT id FROM currency WHERE currency = 'GBP'),
    TRUE,
    (SELECT id FROM shipping_charge_class WHERE class = 'Same Day'),
    (SELECT id FROM channel WHERE web_name = 'OUTNET-INTL'),
    0
);

COMMIT;
