BEGIN;

UPDATE system_config.config_group
 SET active = false
 WHERE name = 'Welcome_Pack' AND channel_id = (SELECT id FROM channel WHERE web_name ilike 'MRP%');

COMMIT;


