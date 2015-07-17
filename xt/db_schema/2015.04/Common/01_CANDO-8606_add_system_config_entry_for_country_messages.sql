-- CANDO-8606: Add a new System Config entry for messages to be displayed,
-- when selecting a country whilst editing an address.

BEGIN WORK;

INSERT INTO system_config.config_group (
    name,
    channel_id,
    active
) VALUES (
    'AddressFormatingMessagesByCountry',
    NULL,
    TRUE
);

INSERT INTO system_config.config_group_setting (
    config_group_id,
    setting,
    value,
    sequence,
    active
) VALUES (
    ( SELECT id FROM system_config.config_group WHERE name = 'AddressFormatingMessagesByCountry' ),
    'DE',
    'address_line_1:Street name must come before house number for German addresses',
    0,
    TRUE
);

COMMIT WORK;
