BEGIN;

SELECT setval(
   'system_config.config_group_id_seq',
      ( SELECT MAX(id) FROM system_config.config_group )
);

SELECT setval(
   'system_config.config_group_setting_id_seq',
      ( SELECT MAX(id) FROM system_config.config_group_setting )
);



INSERT INTO system_config.config_group (
    name, channel_id, active
) VALUES (
    'Internal Staff Order',
    (SELECT id FROM public.channel WHERE web_name = 'NAP-AM'),
    TRUE
);
INSERT INTO system_config.config_group_setting (
    config_group_id, setting, value
) VALUES (
    (SELECT id FROM system_config.config_group WHERE
        name = 'Internal Staff Order'
        AND channel_id = (
            SELECT id FROM public.channel WHERE web_name = 'NAP-AM'
        )
    ),
    'shipping_sku',
    '920008-001'
);



INSERT INTO system_config.config_group (
    name, channel_id, active
) VALUES (
    'Internal Staff Order',
    (SELECT id FROM public.channel WHERE web_name = 'OUTNET-AM'),
    TRUE
);
INSERT INTO system_config.config_group_setting (
    config_group_id, setting, value
) VALUES (
    (SELECT id FROM system_config.config_group WHERE
        name = 'Internal Staff Order'
        AND channel_id = (
            SELECT id FROM public.channel WHERE web_name = 'OUTNET-AM'
        )
    ),
    'shipping_sku',
    '920010-001'
);



INSERT INTO system_config.config_group (
    name, channel_id, active
) VALUES (
    'Internal Staff Order',
    (SELECT id FROM public.channel WHERE web_name = 'MRP-AM'),
    TRUE
);
INSERT INTO system_config.config_group_setting (
    config_group_id, setting, value
) VALUES (
    (SELECT id FROM system_config.config_group WHERE
        name = 'Internal Staff Order'
        AND channel_id = (
            SELECT id FROM public.channel WHERE web_name = 'MRP-AM'
        )
    ),
    'shipping_sku',
    '920009-001'
);


COMMIT;
