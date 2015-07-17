-- cando-1836
--9000322-001 - sjipping skus for staff orders for dc3

BEGIN WORK;


INSERT INTO shipping_charge (
    sku, description, charge, currency_id, flat_rate, class_id, channel_id, premier_routing_id, is_customer_facing
) VALUES (
    '9000322-001','Internal Staff Order', 0.00,
    (SELECT id FROM currency WHERE currency = 'HKD'),
    TRUE,
    (SELECT id FROM shipping_charge_class WHERE class = 'Same Day'),
    (SELECT id FROM channel WHERE web_name = 'NAP-APAC'),
    0,
    FALSE
);

DELETE FROM system_config.config_group_setting WHERE
config_group_id=(SELECT id FROM system_config.config_group WHERE
        name = 'Internal Staff Order'
        AND channel_id = (
            SELECT id FROM public.channel WHERE web_name = 'NAP-APAC'
        )
    );

SELECT setval(
   'system_config.config_group_setting_id_seq',
      ( SELECT MAX(id) FROM system_config.config_group_setting )
);

INSERT INTO system_config.config_group_setting (
    config_group_id, setting, value
) VALUES (
    (SELECT id FROM system_config.config_group WHERE
        name = 'Internal Staff Order'
        AND channel_id = (
            SELECT id FROM public.channel WHERE web_name = 'NAP-APAC'
        )
    ),
    'shipping_sku',
    '9000322-001'
);

COMMIT WORK;

