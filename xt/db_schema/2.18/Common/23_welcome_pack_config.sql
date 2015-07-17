BEGIN;
  INSERT INTO system_config.config_group (name) VALUES ('Welcome_Pack');
  INSERT INTO system_config.config_group_setting (config_group_id, setting, value) 
    VALUES (
    (SELECT id FROM  system_config.config_group WHERE name = 'Welcome_Pack'), 
    'state',
    'Off');
COMMIT;
