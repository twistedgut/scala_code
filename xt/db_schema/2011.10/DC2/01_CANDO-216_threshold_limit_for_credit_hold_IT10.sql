-- CANDO-216: System Config Section for a Threshold to put Orders on Hold if
--            they are NOT requiring a Delivery Signature. This is per Currency
--            which for DC2 is only USD

BEGIN WORK;

-- first create a new group per Sales Channel
INSERT INTO system_config.config_group (name,channel_id)
SELECT  'No_Delivery_Signature_Credit_Hold_Threshold',
        id
FROM    channel
ORDER BY id
;

-- now create a setting per Group
INSERT INTO system_config.config_group_setting ( config_group_id, setting, value )
SELECT  id,
        'USD',
        2000
FROM    system_config.config_group
WHERE   name = 'No_Delivery_Signature_Credit_Hold_Threshold'
ORDER BY id
;

COMMIT WORK;
