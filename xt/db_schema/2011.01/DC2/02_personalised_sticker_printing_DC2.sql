 BEGIN;

    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='personalized_stickers' and channel_id=2),'print_sticker',1,0,false);

    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='personalized_stickers' and channel_id=4),'print_sticker',1,0,false);

    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='personalized_stickers' and channel_id=6),'print_sticker',1,0,true);

    insert into system_config.config_group (name,channel_id,active) 
        values ('PackingPrinterList',null,true);
COMMIT;

BEGIN;

    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 1','10.7.7.31',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 2','10.7.7.32',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 3','10.7.7.33',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 4','10.7.7.34',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 5','10.7.7.35',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 6','10.7.7.36',0,true);
     
COMMIT; 
