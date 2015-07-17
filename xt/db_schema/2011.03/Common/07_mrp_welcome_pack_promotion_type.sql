BEGIN;


INSERT INTO promotion_type (
    channel_id, name, product_type, weight, fabric, origin, hs_code,
    promotion_class_id
) VALUES (
    (SELECT id FROM channel WHERE web_name ilike 'MRP%'),
    'Welcome Pack - English',
    'Pocket Square (Promotional)',
    0.016,
    '100% Cotton',
    'United Kingdom',
    '621320',
    (SELECT id FROM promotion_class WHERE class = 'Free Gift')
);


INSERT INTO country_promotion_type_welcome_pack (
    country_id, promotion_type_id
) VALUES (
    (SELECT id FROM country WHERE code = 'GB'),
    (SELECT id FROM promotion_type
        WHERE name = 'Welcome Pack - English'
        AND channel_id = (SELECT id FROM channel WHERE web_name ilike 'MRP%'))
);


UPDATE system_config.config_group SET active = true WHERE
    name = 'Welcome_Pack' AND channel_id = (
        SELECT id FROM channel WHERE web_name ilike 'MRP%'
    );

COMMIT;
