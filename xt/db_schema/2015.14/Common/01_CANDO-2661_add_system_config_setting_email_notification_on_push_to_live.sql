--
-- CANDO-2661: New system_config.config_group_setting for FraudRules
--             push_to_live_email_notice_recipient defaults to Off
--

BEGIN WORK;

INSERT INTO system_config.config_group ( name, active )
VALUES ( 'CONRAD', true );

INSERT INTO system_config.config_group_setting (
    config_group_id,
    setting,
    value,
    active
)
VALUES
(
    ( SELECT id FROM system_config.config_group WHERE NAME = 'CONRAD' ),
    'email_notification_on_push_to_live',
    'On',
    true
),
(
    ( SELECT id FROM system_config.config_group WHERE NAME = 'CONRAD' ),
    'push_to_live_email_notice_recipient',
    'CONRADLiveUpdates@net-a-porter.com',
    true
);

COMMIT WORK;
