BEGIN;
    INSERT INTO system_config.config_group (name) VALUES ('Order_Credit_Check');
    INSERT INTO system_config.config_group_setting (config_group_id, setting, value)
    VALUES (
        (SELECT id FROM  system_config.config_group WHERE name = 'Order_Credit_Check'),
        'total_order_period',
        '6 Months');
COMMIT;



