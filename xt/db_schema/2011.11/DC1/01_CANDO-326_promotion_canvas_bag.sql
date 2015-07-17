-- CANDO-326: Add the Canvas Bag Details to the 'promotion_type' Table

BEGIN WORK;

INSERT INTO promotion_type ( name, product_type, weight, fabric, origin, hs_code, promotion_class_id, channel_id ) VALUES (
    'THE OUTNET tote',
    'Shopper bag',
    0.106,
    '100% cotton canvas Size: 350 x 400mm. Complete with 2 x handles 35mm x 500mm long',
    'China',
    '420222',
    (
        SELECT  id
        FROM    promotion_class
        WHERE   class = 'Free Gift'
    ),
    (
        SELECT  c.id
        FROM    channel c
                JOIN business b ON b.id = c.business_id
        WHERE   b.config_section = 'OUTNET'
    )
);

COMMIT WORK;
