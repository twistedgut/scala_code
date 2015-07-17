-- CANDO-80: System Config for Communicating to Customers by SMS or Email
--           Global one for SMS per Sales Channel.
--           New Per Sales Channel Premier Delivery Section which includes settings for notifying Customers.

BEGIN WORK;

--
-- Create new Global per Sales Channel Customer Communicaion
--
INSERT INTO system_config.config_group (name,channel_id)
SELECT  'Customer_Communication',
        id
FROM    channel
ORDER BY id
;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value)
SELECT  cg.id,
        'SMS',
        'On'
FROM    system_config.config_group cg
WHERE   cg.name = 'Customer_Communication'
UNION
SELECT  cg.id,
        'Email',
        'On'
FROM    system_config.config_group cg
WHERE   cg.name = 'Customer_Communication'
ORDER BY 1
;


--
-- Create Premier Delivery Group
--
INSERT INTO system_config.config_group (name,channel_id)
SELECT  'Premier_Delivery',
        id
FROM    channel
ORDER BY id
;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value)
SELECT  cg.id,
        'SMS Alert',
        CASE b.config_section
            WHEN 'NAP' THEN 'On'
            WHEN 'MRP' THEN 'On'
            ELSE 'Off'
        END
FROM    system_config.config_group cg
        JOIN channel ch ON ch.id = cg.channel_id
        JOIN business b ON b.id = ch.business_id
WHERE   cg.name = 'Premier_Delivery'
UNION
SELECT  cg.id,
        'Email Alert',
        CASE b.config_section
            WHEN 'NAP' THEN 'On'
            WHEN 'MRP' THEN 'On'
            ELSE 'Off'
        END
FROM    system_config.config_group cg
        JOIN channel ch ON ch.id = cg.channel_id
        JOIN business b ON b.id = ch.business_id
WHERE   cg.name = 'Premier_Delivery'
UNION
-- The number of failed attempts at delivery/collection
-- that means the Hold Order Delivery alert is then sent
SELECT  cg.id,
        'send_hold_alert_threshold',
        '3'
FROM    system_config.config_group cg
WHERE   cg.name = 'Premier_Delivery'
ORDER BY 1,2
;

COMMIT WORK;
