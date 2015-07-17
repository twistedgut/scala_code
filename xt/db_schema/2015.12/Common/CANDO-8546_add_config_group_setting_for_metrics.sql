--
-- CANDO-8546: Add config_group_setting for can_send_metrics
-- This will allow us to turn on or off the sending of metrics to Graphite
-- easily in case it causes problems.
--

BEGIN WORK;

INSERT INTO system_config.config_group ( name, active )
VALUES (
    'Send_Metrics_to_Graphite', true
);

INSERT INTO system_config.config_group_setting
    ( config_group_id, setting, value, active )
VALUES (
    ( SELECT id FROM system_config.config_group WHERE name = 'Send_Metrics_to_Graphite' ),
    'is_active',
    1,
    true
);

COMMIT WORK;
