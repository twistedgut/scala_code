-- Ticket       : CANDO-8584
-- Description  : Adding a System Config entry for Klarna Payment to be used
--                by XT::Order::Parser::PublicWebsiteXML.

BEGIN WORK;

INSERT INTO system_config.config_group (
    name,
    channel_id,
    active
) VALUES (
    'OrderImporterPreParser',
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
        ( SELECT id FROM system_config.config_group WHERE name = 'OrderImporterPreParser' ),
        'tender_type-klarna',
        'Card',
        0,
        TRUE
);

COMMIT;

