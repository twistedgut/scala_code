BEGIN;

INSERT INTO shipping_account__country VALUES (
    default, 
    (SELECT id FROM shipping_account WHERE channel_id = 
        (SELECT id from channel where name = 'JIMMYCHOO.COM') 
        AND name = 'Domestic'), 
    'United States', 
    (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));

UPDATE shipping_account SET 
    account_number = 'X2477X', 
    shipping_number = 'X2477X', 
    return_account_number = 'X2477X'
WHERE channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM') 
    AND name = 'Domestic';

UPDATE shipping_account SET 
    account_number = '846013808', 
    shipping_number = '', 
    return_account_number = ''
WHERE channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')
    AND name = 'International';

INSERT INTO system_config.config_group_setting VALUES (
    default,
    (SELECT id FROM system_config.config_group WHERE name = 'Carrier_Automation_State'
        AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')),
    'state',
    'On',
    0,
    true
);

COMMIT;
