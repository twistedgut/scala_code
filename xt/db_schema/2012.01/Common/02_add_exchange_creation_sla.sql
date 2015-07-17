-- Add an arbitrarily high SLA at the point when exchanges are created

BEGIN;
    INSERT INTO system_config.config_group_setting (config_group_id, setting, value, active) VALUES (
        (SELECT id FROM system_config.config_group WHERE name = 'default_slas'),
        'sla_exchange_creation',
        '30 days',
        true
    );
COMMIT;
