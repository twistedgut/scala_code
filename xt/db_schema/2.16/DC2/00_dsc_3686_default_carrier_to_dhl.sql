BEGIN;

INSERT INTO shipping_account__country
(
    shipping_account_id,
    country,
    channel_id
) VALUES (
    (SELECT id FROM shipping_account WHERE
        carrier_id = (SELECT id FROM carrier WHERE name = 'UPS')
        AND name = 'Domestic'
        AND channel_id = (SELECT id FROM channel
            WHERE name = 'NET-A-PORTER.COM')),
    'United States',
    (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
);

INSERT INTO shipping_account__country
(
    shipping_account_id,
    country,
    channel_id
) VALUES (
    (SELECT id FROM shipping_account WHERE
        carrier_id = (SELECT id FROM carrier WHERE name = 'UPS')
        AND name = 'Domestic'
        AND channel_id = (SELECT id FROM channel 
            WHERE name = 'theOutnet.com')),
    'United States',
    (SELECT id FROM channel WHERE name = 'theOutnet.com')
);

COMMIT;
