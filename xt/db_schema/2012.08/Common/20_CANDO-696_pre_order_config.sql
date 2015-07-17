BEGIN WORK;

-- Create groups.
INSERT INTO system_config.config_group
(
    name,
    channel_id,
    active
)
VALUES
(
    'PreOrder',
    (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
    TRUE
),
(
    'PreOrder',
    ( SELECT id FROM channel WHERE name = 'theOutnet.com'),
    TRUE
),
(
    'PreOrder',
    (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
    TRUE
),
(
    'PreOrder',
    (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'),
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
VALUES
(
    (SELECT id FROM system_config.config_group WHERE name = 'PreOrder' and channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM') AND active),
    'is_active',
    0,
    0,
    TRUE
),
(
    (SELECT id FROM system_config.config_group WHERE name = 'PreOrder' and channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com') AND active),
    'is_active',
    0,
    0,
    TRUE
),
(
    (SELECT id FROM system_config.config_group WHERE name = 'PreOrder' and channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM') AND active),
    'is_active',
    0,
    0,
    TRUE
),
(
    (SELECT id FROM system_config.config_group WHERE name = 'PreOrder' and channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM') AND active),
    'is_active',
    0,
    0,
    TRUE
);

COMMIT;

