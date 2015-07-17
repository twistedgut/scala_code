BEGIN;

    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='personalized_stickers' and channel_id=1),'print_sticker',1,0,false);

    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='personalized_stickers' and channel_id=3),'print_sticker',1,0,false);

    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='personalized_stickers' and channel_id=5),'print_sticker',1,0,true);

    insert into system_config.config_group (name,channel_id,active) 
        values ('PackingPrinterList',null,true);
COMMIT;

BEGIN;

    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 1','10.3.3.235',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 2','10.3.3.236',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 3','10.3.3.237',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 4','10.3.3.238',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 5','10.3.3.239',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 6','10.3.3.242',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 7','10.3.3.243',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 8','10.3.3.244',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 9','10.3.3.245',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 10','10.3.3.246',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 11','10.3.3.247',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 12','10.3.3.248',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 13','10.3.3.249',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 14','10.3.3.250',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 15','10.3.3.251',0,true);
    insert into system_config.config_group_setting (config_group_id, setting, value, sequence, active)
        values ((select id from system_config.config_group where name='PackingPrinterList'),'MRP Printer 16','10.3.3.252',0,true);
     
COMMIT;
