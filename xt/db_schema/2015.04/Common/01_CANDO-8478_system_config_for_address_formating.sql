-- Ticket       : CANDO-8478
-- Description  : Add a System Config entry for address formatting for Germany,
--                used by XT::Domain::Payment::AddressFormat.
-- Author       : Andrew Benson

BEGIN WORK;

INSERT INTO system_config.config_group (
    name,
    channel_id,
    active
) VALUES (
    'PaymentAddressFormatForCountry',
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
    ( SELECT id FROM system_config.config_group WHERE name = 'PaymentAddressFormatForCountry' ),
    'DE',
    'SplitHouseNumber',
    0,
    TRUE
);

COMMIT;

