--
-- CANDO-8422: Add system_config settings for order search limit
--

BEGIN WORK;

INSERT INTO system_config.config_group ( name, active ) VALUES
    ( 'order_search', true );

INSERT INTO system_config.config_group_setting (
    config_group_id,
    setting,
    value,
    active
) VALUES (
    ( SELECT id FROM system_config.config_group WHERE name = 'order_search' ),
    'result_limit',
    10000,
    true
);

COMMIT;
