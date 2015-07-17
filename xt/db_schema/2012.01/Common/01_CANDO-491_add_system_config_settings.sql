-- CANDO-491: Add system config settings.

BEGIN WORK;

-- Create groups.
INSERT INTO system_config.config_group (
    name,
    channel_id,
    active
)
VALUES (
    'CreditHoldExceptionParams',
    ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' ),
    TRUE
),(
    'CreditHoldExceptionParams',
    ( SELECT id FROM channel WHERE name = 'theOutnet.com' ),
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
    ( SELECT id FROM system_config.config_group WHERE name = 'CreditHoldExceptionParams' and channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' ) AND active ),
    'month',
    '9',
    0,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'CreditHoldExceptionParams' and channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' ) AND active ),
    'order_total',
    '5000',
    0,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'CreditHoldExceptionParams' and channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' ) AND active ),
    'include_channel',
    (SELECT config_section FROM business WHERE name='NET-A-PORTER.COM'),
    1,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'CreditHoldExceptionParams' and channel_id = ( SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM' ) AND active ),
    'include_channel',
    (SELECT config_section FROM business WHERE name='theOutnet.com'),
    2,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'CreditHoldExceptionParams' and channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' ) AND active ),
    'month',
    '9',
    0,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'CreditHoldExceptionParams' and channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' ) AND active ),
    'order_total',
    '5000',
    0,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'CreditHoldExceptionParams' and channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' ) AND active ),
    'include_channel',
    (SELECT config_section FROM business WHERE name='theOutnet.com'),
    1,
    TRUE
),(
    ( SELECT id FROM system_config.config_group WHERE name = 'CreditHoldExceptionParams' and channel_id = ( SELECT id FROM channel WHERE name = 'theOutnet.com' ) AND active ),
    'include_channel',
    (SELECT config_section FROM business WHERE name='NET-A-PORTER.COM'),
    2,
    TRUE
);

COMMIT;

