-- CANDO-490: Add system config settings.

BEGIN WORK;

-- Create groups.
INSERT INTO system_config.config_group (
    name,
    channel_id,
    active
)
VALUES (
    'FraudCheckRatingAdjustment',
    ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' ),
    TRUE
),(
    'FraudCheckRatingAdjustment',
    ( SELECT id FROM channel WHERE name = 'theOutnet.com' ),
    TRUE
),(
    'FraudCheckRatingAdjustment',
    ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' ),
    TRUE
),(
    'FraudCheckRatingAdjustment',
    ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' ),
    TRUE
);

-- Create settings/values.
INSERT INTO system_config.config_group_setting (
    config_group_id,
    setting,
    value,
    sequence,
    active
)
VALUES (
    ( SELECT id FROM system_config.config_group WHERE name = 'FraudCheckRatingAdjustment' and channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' ) AND active ),
    'card_check_rating',
    '150',
    0,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'FraudCheckRatingAdjustment' and channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' ) AND active ),
    'card_check_rating',
    '150',
    0,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'FraudCheckRatingAdjustment' and channel_id = ( SELECT id FROM channel WHERE name = 'MRPORTER.COM' ) AND active ),
    'card_check_rating',
    '0',
    0,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'FraudCheckRatingAdjustment' and channel_id = ( SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM' ) AND active ),
    'card_check_rating',
    '150',
    0,
    TRUE
);

COMMIT;


