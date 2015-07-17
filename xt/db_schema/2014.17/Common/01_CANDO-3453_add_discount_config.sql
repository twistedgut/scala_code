-- CANDO-3453: Add Discount Config options
--             to the System Config

BEGIN WORK;

--
-- Turn ON Discounts for NAP & set Max & Increment values
--
INSERT INTO system_config.config_group_setting ( config_group_id, setting, value ) VALUES
(
    (
        SELECT  cg.id
        FROM    system_config.config_group cg
                    JOIN channel ch ON ch.id = cg.channel_id
                    JOIN business b ON  b.id = ch.business_id
                                   AND  b.config_section = 'NAP'
        WHERE   cg.name = 'PreOrder'
    ),
    'can_apply_discount',
    '1'
),
(
    (
        SELECT  cg.id
        FROM    system_config.config_group cg
                    JOIN channel ch ON ch.id = cg.channel_id
                    JOIN business b ON  b.id = ch.business_id
                                   AND  b.config_section = 'NAP'
        WHERE   cg.name = 'PreOrder'
    ),
    'max_discount',
    '30'
),
(
    (
        SELECT  cg.id
        FROM    system_config.config_group cg
                    JOIN channel ch ON ch.id = cg.channel_id
                    JOIN business b ON  b.id = ch.business_id
                                   AND  b.config_section = 'NAP'
        WHERE   cg.name = 'PreOrder'
    ),
    'discount_increment',
    '5'
)
;

--
-- Set-up Categories with initially a ZERO default discount
-- which can be changed later if asked to do so.
--

-- create a new Config Group
INSERT INTO system_config.config_group ( name, channel_id ) VALUES (
    'PreOrderDiscountCategory',
    (
        SELECT  ch.id
        FROM    channel ch
                    JOIN business b ON b.id = ch.business_id
                                   AND b.config_section = 'NAP'
    )
);

-- create Settings
INSERT INTO system_config.config_group_setting ( config_group_id, setting, value )
SELECT  cg.id,
        cc.category,
        '0'
FROM    customer_category cc,
        system_config.config_group cg
            JOIN channel ch ON ch.id = cg.channel_id
            JOIN business b ON  b.id = ch.business_id
                           AND  b.config_section = 'NAP'
WHERE   cg.name = 'PreOrderDiscountCategory'
AND     cc.category IN (
    'EIP',
    'EIP Centurion',
    'EIP Premium',
    'EIP Elite'
)
;

--
-- Turn OFF Discounts for other Sales Channels
--
INSERT INTO system_config.config_group_setting ( config_group_id, setting, value )
SELECT  cg.id,
        'can_apply_discount',
        '0'
FROM    system_config.config_group cg
            JOIN channel ch ON ch.id = cg.channel_id
            JOIN business b ON  b.id = ch.business_id
                           AND  b.config_section != 'NAP'
WHERE   cg.name = 'PreOrder'
;

COMMIT WORK;
