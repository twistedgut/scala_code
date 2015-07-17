BEGIN;

INSERT INTO system_config.config_group(name, channel_id, active)
    VALUES ('SendToMercury', (SELECT id from channel where name = 'NET-A-PORTER.COM') , true),
           ('SendToMercury', (SELECT id from channel where name = 'theOutnet.com'), true),
           ('SendToMercury', (SELECT id from channel where name = 'MRPORTER.COM'), true),
           ('SendToMercury', (SELECT id from channel where name = 'JIMMYCHOO.COM'), true);

INSERT INTO system_config.config_group_setting(config_group_id, setting, value, active)
    VALUES (
        (SELECT id from system_config.config_group
                WHERE name = 'SendToMercury'
                AND channel_id = (SELECT id from channel where name = 'NET-A-PORTER.COM')),
        'can_send_shipment_updates',
        'Off',
        true),
        ((SELECT id from system_config.config_group
                WHERE name = 'SendToMercury'
                AND channel_id = (SELECT id from channel where name = 'theOutnet.com')),
        'can_send_shipment_updates',
        'Off',
        true),
        ((SELECT id from system_config.config_group
                WHERE name = 'SendToMercury'
                AND channel_id = (SELECT id from channel where name = 'MRPORTER.COM')),
        'can_send_shipment_updates',
        'Off',
        true),
        ((SELECT id from system_config.config_group
                WHERE name = 'SendToMercury'
                AND channel_id = (SELECT id from channel where name = 'JIMMYCHOO.COM')),
        'can_send_shipment_updates',
        'Off',
        true);

COMMIT;
