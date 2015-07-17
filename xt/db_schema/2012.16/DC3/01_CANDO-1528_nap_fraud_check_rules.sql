--CANDO-1528 : Update fraud check rules for DC3

BEGIN WORK;

-- order total value for NAP
UPDATE credit_hold_threshold
SET value=31000
WHERE name='Single Order Value'
AND channel_id =(
             SELECT id FROM channel WHERE
             web_name='NAP-APAC' AND
             name='NET-A-PORTER.COM'
    );

--6 months spend limit for NAP
UPDATE credit_hold_threshold
SET value=12400513
WHERE name='Total Order Value'
AND channel_id =(
             SELECT id FROM channel WHERE
             web_name='NAP-APAC' AND
             name='NET-A-PORTER.COM'
    );

--1 week spend limit for NAP
UPDATE credit_hold_threshold
SET value=12400513
WHERE name='Weekly Order Value'
AND channel_id =(
             SELECT id FROM channel WHERE
             web_name='NAP-APAC' AND
             name='NET-A-PORTER.COM'
    );



-- Australia's specific low risk order attributes/thresholds
UPDATE system_config.config_group_setting
SET value=21750
where  setting='NAP-APAC_Order_Threshold'
AND config_group_id = (
        SELECT id FROM system_config.config_group WHERE name = 'AUOrderRiskAttributes'
    );

-- NewZealand specific low risk order attributes/thresholds
UPDATE system_config.config_group_setting
SET value=21750
where  setting='NAP-APAC_Order_Threshold'
AND config_group_id = (
        SELECT id FROM system_config.config_group WHERE name = 'NZOrderRiskAttributes'
    );

-- Cyprus specific low risk order attributes/thresholds
UPDATE system_config.config_group_setting
SET value=21750
where  setting='NAP-APAC_Order_Threshold'
AND config_group_id = (
        SELECT id FROM system_config.config_group WHERE name = 'CYOrderRiskAttributes'
    );

-- Norway specific low risk order attributes/thresholds
UPDATE system_config.config_group_setting
SET value=21750
where  setting='NAP-APAC_Order_Threshold'
AND config_group_id = (
        SELECT id FROM system_config.config_group WHERE name = 'NOOrderRiskAttributes'
    );


-- Denmark specific low risk order attributes/thresholds
UPDATE system_config.config_group_setting
SET value=21750
where  setting='NAP-APAC_Order_Threshold'
AND config_group_id = (
        SELECT id FROM system_config.config_group WHERE name = 'DKOrderRiskAttributes'
    );

-- Finland specific low risk order attributes/thresholds
UPDATE system_config.config_group_setting
SET value=21750
where  setting='NAP-APAC_Order_Threshold'
AND config_group_id = (
        SELECT id FROM system_config.config_group WHERE name = 'FIOrderRiskAttributes'
    );

-- Saudi Arabia specific low risk order attributes/thresholds
UPDATE system_config.config_group_setting
SET value=21750
where  setting='NAP-APAC_Order_Threshold'
AND config_group_id = (
        SELECT id FROM system_config.config_group WHERE name = 'SAOrderRiskAttributes'
    );


-- Credit hold exception for order total value for nap
UPDATE system_config.config_group_setting
set value=62142
where setting ='order_total'
AND config_group_id = (
    SELECT id FROM system_config.config_group WHERE name = 'CreditHoldExceptionParams' and channel_id = ( SELECT id FROM channel WHERE web_name='NAP-APAC' AND name = 'NET-A-PORTER.COM' )
);

COMMIT;

