-- CANDO-7910: Create system config entries for enabling and disabling
--             customer value being pushed to BOSH.

BEGIN WORK;

INSERT INTO system_config.config_group (
    name,
    channel_id,
    active
) VALUES (
    'SendToBOSH',
    null,
    TRUE
);

INSERT INTO system_config.config_group_setting (
    config_group_id,
    setting,
    value,
    sequence,
    active
) VALUES (
    ( SELECT id FROM system_config.config_group WHERE name = 'SendToBOSH' AND channel_id is NULL ),
    'Customer Value',
    'Off',
    0,
    TRUE
);

COMMIT;
