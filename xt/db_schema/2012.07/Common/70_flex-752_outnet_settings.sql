BEGIN;


INSERT INTO correspondence_subject (
    subject,
    description,
    enabled,
    channel_id
) VALUES (
    'Premier Delivery',
    'Premier Delivery/Collection Notification',
    true,
    (select id FROM channel WHERE name = 'theOutnet.com')
);


-- Phone method
INSERT INTO correspondence_subject_method (
    correspondence_subject_id,
    correspondence_method_id,
    can_opt_out,
    default_can_use,
    enabled,
    send_from,
    copy_to_crm,
    notify_on_failure
) VALUES (
    (SELECT id FROM correspondence_subject
        WHERE subject = 'Premier Delivery'
        AND channel_id = (select id FROM channel WHERE name = 'theOutnet.com')),
    (SELECT id FROM correspondence_method WHERE method = 'Phone'),
    true,
    false,
    true,
    null,
    false,
    null
),(
    (SELECT id FROM correspondence_subject
        WHERE subject = 'Premier Delivery'
        AND channel_id = (select id FROM channel WHERE name = 'theOutnet.com')),
    (SELECT id FROM correspondence_method WHERE method = 'Email'),
    true,
    true,
    true,
    'premier_email',
    false,
    null
),(
    (SELECT id FROM correspondence_subject
        WHERE subject = 'Premier Delivery'
        AND channel_id = (select id FROM channel WHERE name = 'theOutnet.com')),
    (SELECT id FROM correspondence_method WHERE method = 'SMS'),
    true,
    true,
    true,
    null,
    false,
    'premier_email'
);


UPDATE system_config.config_group_setting SET value = 'On' WHERE
    config_group_id = (
        SELECT id 
        FROM system_config.config_group 
        WHERE name = 'Premier_Delivery' 
        AND channel_id = (select id FROM channel WHERE name = 'theOutnet.com')
    )
AND setting = 'SMS Alert';


UPDATE system_config.config_group_setting SET value = 'On' WHERE
    config_group_id = (
        SELECT id 
        FROM system_config.config_group 
        WHERE name = 'Premier_Delivery'
        AND channel_id = (select id FROM channel WHERE name = 'theOutnet.com')
    )
AND setting = 'Email Alert';


COMMIT;
