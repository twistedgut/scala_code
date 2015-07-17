-- Store Credit refunds aren't allowed for Jimmy Choo
-- http://jira.nap/browse/CANDO-8706

BEGIN WORK;

INSERT INTO system_config.config_group (name, channel_id, active) VALUES (
    'Refund',
    (SELECT id FROM public.channel WHERE name = 'JIMMYCHOO.COM'),
    true
);

INSERT INTO system_config.config_group_setting (config_group_id, setting, value, active) VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'Refund'),
    'deny_store_credit',
    1,
    true
);

COMMIT WORK;