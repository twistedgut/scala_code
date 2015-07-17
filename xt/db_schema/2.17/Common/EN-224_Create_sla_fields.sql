BEGIN;
--------------------------------------------------------------------------------------
--                        Adding fields required for SLAs        
--------------------------------------------------------------------------------------

ALTER TABLE     public.shipment
ADD COLUMN      sla_priority integer;
ALTER TABLE     public.shipment
ADD COLUMN      sla_cutoff timestamp;

insert into system_config.config_group (name,active) values ('despatch_slas',true);
insert into system_config.config_group_setting (config_group_id,setting,value,sequence,active) values (
    (select id from system_config.config_group where name='despatch_slas'),
    'nap_standard',
    '1 day',
    0,
    true
);
insert into system_config.config_group_setting (config_group_id,setting,value,sequence,active) values (
    (select id from system_config.config_group where name='despatch_slas'),
    'nap_sale',
    '2 days',
    0,
    true
); 
insert into system_config.config_group_setting (config_group_id,setting,value,sequence,active) values (
    (select id from system_config.config_group where name='despatch_slas'),
    'outnet_standard',
    '2 days',
    0,
    true
);
insert into system_config.config_group_setting (config_group_id,setting,value,sequence,active) values (
    (select id from system_config.config_group where name='despatch_slas'),
    'outnet_sale',
    '2 days',
    0,
    true
); 
insert into system_config.config_group_setting (config_group_id,setting,value,sequence,active) values (
    (select id from system_config.config_group where name='despatch_slas'),
    'premier',
    '1 hour',
    0,
    true
); 
--------------------------------------------------------------------------------------
COMMIT;
