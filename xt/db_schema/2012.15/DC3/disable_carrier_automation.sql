-- carrier automation config settings for DC3: no automatioan

BEGIN;

UPDATE system_config.config_group_setting
   SET value = 'Off'
 WHERE config_group_id IN (
   SELECT id
     FROM system_config.config_group
    WHERE name = 'Carrier_Automation_State'
 );

COMMIT;
