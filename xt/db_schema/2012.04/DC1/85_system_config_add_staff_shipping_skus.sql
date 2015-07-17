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
    (SELECT id FROM public.channel WHERE web_name = 'NAP-INTL'),
    TRUE
);
INSERT INTO system_config.config_group_setting (
    config_group_id, setting, value
) VALUES (
    (SELECT id FROM system_config.config_group WHERE
        name = 'Internal Staff Order'
        AND channel_id = (
            SELECT id FROM public.channel WHERE web_name = 'NAP-INTL'
        )
    ),
    'shipping_sku',
    '920005-001'
);



INSERT INTO system_config.config_group (
    name, channel_id, active
) VALUES (
    'Internal Staff Order',
    (SELECT id FROM public.channel WHERE web_name = 'OUTNET-INTL'),
    TRUE
);
INSERT INTO system_config.config_group_setting (
    config_group_id, setting, value
) VALUES (
    (SELECT id FROM system_config.config_group WHERE
        name = 'Internal Staff Order'
        AND channel_id = (
            SELECT id FROM public.channel WHERE web_name = 'OUTNET-INTL'
        )
    ),
    'shipping_sku',
    '920007-001'
);



INSERT INTO system_config.config_group (
    name, channel_id, active
) VALUES (
    'Internal Staff Order',
    (SELECT id FROM public.channel WHERE web_name = 'MRP-INTL'),
    TRUE
);
INSERT INTO system_config.config_group_setting (
    config_group_id, setting, value
) VALUES (
    (SELECT id FROM system_config.config_group WHERE
        name = 'Internal Staff Order'
        AND channel_id = (
            SELECT id FROM public.channel WHERE web_name = 'MRP-INTL'
        )
    ),
    'shipping_sku',
    '920006-001'
);


COMMIT;
