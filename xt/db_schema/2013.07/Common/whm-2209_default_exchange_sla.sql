-- Update the default exchange SLA to 1 day (actually... 24 hours - it's easier
-- to work in hours)

BEGIN;
    UPDATE system_config.config_group_setting cgs
    SET value = '1 day'
    FROM system_config.config_group cg
    WHERE cgs.setting = 'sla_exchange_creation'
    AND cgs.config_group_id = cg.id;
COMMIT;
