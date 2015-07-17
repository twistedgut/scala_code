BEGIN;

INSERT INTO system_config.config_group ( name, channel_id, active )
VALUES ('dispatch_slas', 2, true );

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_standard', value, sequence, active
  FROM system_config.config_group_setting
    WHERE setting = 'nap_standard';

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_sale', value, sequence, active
  FROM system_config.config_group_setting
    WHERE setting = 'nap_sale';

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_premier', value, sequence, active
  FROM system_config.config_group_setting
    WHERE setting = 'premier';


INSERT INTO system_config.config_group ( name, channel_id, active )
VALUES ('dispatch_slas', 4, true );

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_standard', value, sequence, active
  FROM system_config.config_group_setting
    WHERE setting = 'outnet_standard';

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_sale', value, sequence, active
  FROM system_config.config_group_setting
    WHERE setting = 'outnet_sale';

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_premier', value, sequence, active
  FROM system_config.config_group_setting
    WHERE setting = 'premier';


INSERT INTO system_config.config_group ( name, channel_id, active )
VALUES ('dispatch_slas', 6, true );

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_standard', value, sequence, active
  FROM system_config.config_group_setting
    WHERE setting = 'nap_standard';

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_sale', value, sequence, active
  FROM system_config.config_group_setting
    WHERE setting = 'nap_sale';

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_premier', value, sequence, active
  FROM system_config.config_group_setting
    WHERE setting = 'premier';


INSERT INTO system_config.config_group ( name, active )
VALUES ('default_slas', true );

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_standard', '1 day', 0, true;

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_premier', '1 hour', 0, true;

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value, sequence, active )
SELECT currval('system_config.config_group_id_seq'), 'sla_transfer', '1 day', 0, true;


DELETE FROM system_config.config_group_setting where setting IN ('nap_standard','nap_sale','outnet_standard','outnet_sale','premier');
DELETE FROM system_config.config_group where name='despatch_slas';

COMMIT;
