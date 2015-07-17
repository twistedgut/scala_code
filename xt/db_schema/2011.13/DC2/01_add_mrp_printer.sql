BEGIN;

INSERT INTO system_config.config_group_setting
    (config_group_id, setting, value)
    VALUES
    ((SELECT id from system_config.config_group where name = 'PackingPrinterList'),
     'MRP Printer 13', '10.7.7.134' 
    )
;
COMMIT;
