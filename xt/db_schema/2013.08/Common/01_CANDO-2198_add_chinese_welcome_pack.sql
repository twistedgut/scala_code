-- CANDO-2198: Add Chinese Welcome Pack

BEGIN WORK;

INSERT INTO promotion_type (
    name,
    product_type,
    weight,
    fabric,
    origin,
    hs_code,
    promotion_class_id,
    channel_id
)
VALUES (
    'Welcome Pack - Chinese',
    'Tape Measure (Promotional)',
    0.03,
    'Plastic',
    'China',
    901780,
    (
        SELECT  id
        FROM    promotion_class
        WHERE   class = 'Free Gift'
    ),
    (
        SELECT  ch.id
        FROM    channel ch
                    JOIN business b ON b.id = ch.business_id
                                   AND b.config_section = 'NAP'
    )
);

COMMIT WORK;
