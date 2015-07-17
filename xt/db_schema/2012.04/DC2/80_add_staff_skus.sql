BEGIN;

INSERT INTO shipping_charge (
    sku, description, charge, currency_id, flat_rate, class_id, channel_id, premier_routing_id
) VALUES (
    '920008-001','Internal Staff Order', 0.00,
    (SELECT id FROM currency WHERE currency = 'USD'),
    TRUE,
    (SELECT id FROM shipping_charge_class WHERE class = 'Same Day'),
    (SELECT id FROM channel WHERE web_name = 'NAP-AM'),
    0
);

INSERT INTO shipping_charge (
    sku, description, charge, currency_id, flat_rate, class_id, channel_id, premier_routing_id
) VALUES (
    '920009-001','Internal Staff Order', 0.00,
    (SELECT id FROM currency WHERE currency = 'USD'),
    TRUE,
    (SELECT id FROM shipping_charge_class WHERE class = 'Same Day'),
    (SELECT id FROM channel WHERE web_name = 'MRP-AM'),
    0
);

INSERT INTO shipping_charge (
    sku, description, charge, currency_id, flat_rate, class_id, channel_id, premier_routing_id
) VALUES (
    '920010-001','Internal Staff Order', 0.00,
    (SELECT id FROM currency WHERE currency = 'USD'),
    TRUE,
    (SELECT id FROM shipping_charge_class WHERE class = 'Same Day'),
    (SELECT id FROM channel WHERE web_name = 'OUTNET-AM'),
    0
);

COMMIT;
