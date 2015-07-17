BEGIN;

-- Setup the country origin risk group
INSERT INTO system_config.config_group (name,active)
VALUES ('OrderOriginRisk',true);

-- Add the individal country risks
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'OrderOriginRisk'),
    'Australia',
    'Low',
    true
);

INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'OrderOriginRisk'),
    'New Zealand',
    'Low',
    true
);

INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'OrderOriginRisk'),
    'Cyprus',
    'Low',
    true
);

INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'OrderOriginRisk'),
    'Norway',
    'Low',
    true
);

INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'OrderOriginRisk'),
    'Denmark',
    'Low',
    true
);

INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'OrderOriginRisk'),
    'Finland',
    'Low',
    true
);

INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'OrderOriginRisk'),
    'Saudi Arabia',
    'Low',
    true
);

-- Setup config groups for each country's thresholds
INSERT INTO system_config.config_group (name,active)
VALUES ('AUOrderRiskAttributes',true);

INSERT INTO system_config.config_group (name,active)
VALUES ('NZOrderRiskAttributes',true);

INSERT INTO system_config.config_group (name,active)
VALUES ('CYOrderRiskAttributes',true);

INSERT INTO system_config.config_group (name,active)
VALUES ('NOOrderRiskAttributes',true);

INSERT INTO system_config.config_group (name,active)
VALUES ('DKOrderRiskAttributes',true);

INSERT INTO system_config.config_group (name,active)
VALUES ('FIOrderRiskAttributes',true);

INSERT INTO system_config.config_group (name,active)
VALUES ('SAOrderRiskAttributes',true);

-- Australia's specific low risk order attributes/thresholds
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'AUOrderRiskAttributes'),
    'NAP-INTL_Order_Threshold',
    '1750',
    true
);
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'AUOrderRiskAttributes'),
    'OUTNET-INTL_Order_Threshold',
    '600',
    true
)
;
-- New Zealand's specific low risk order attributes/thresholds
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'NZOrderRiskAttributes'),
    'NAP-INTL_Order_Threshold',
    '1750',
    true
);
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'NZOrderRiskAttributes'),
    'OUTNET-INTL_Order_Threshold',
    '600',
    true
);

-- Cyprus's specific low risk order attributes/thresholds
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'CYOrderRiskAttributes'),
    'NAP-INTL_Order_Threshold',
    '1750',
    true
);
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'CYOrderRiskAttributes'),
    'OUTNET-INTL_Order_Threshold',
    '600',
    true
);

-- Norway's specific low risk order attributes/thresholds
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'NOOrderRiskAttributes'),
    'NAP-INTL_Order_Threshold',
    '1750',
    true
);
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'NOOrderRiskAttributes'),
    'OUTNET-INTL_Order_Threshold',
    '600',
    true
);

-- Denmark's specific low risk order attributes/thresholds
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'DKOrderRiskAttributes'),
    'NAP-INTL_Order_Threshold',
    '1750',
    true
);
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'DKOrderRiskAttributes'),
    'OUTNET-INTL_Order_Threshold',
    '600',
    true
);

-- Finland's specific low risk order attributes/thresholds
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'FIOrderRiskAttributes'),
    'NAP-INTL_Order_Threshold',
    '1750',
    true
);
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'FIOrderRiskAttributes'),
    'OUTNET-INTL_Order_Threshold',
    '600',
    true
);

-- Saudia Arabia's specific low risk order attributes/thresholds
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'SAOrderRiskAttributes'),
    'NAP-INTL_Order_Threshold',
    '1750',
    true
);
INSERT INTO system_config.config_group_setting
(config_group_id,setting,value,active)
VALUES (
    (SELECT id FROM system_config.config_group WHERE name = 'SAOrderRiskAttributes'),
    'OUTNET-INTL_Order_Threshold',
    '600',
    true
);

COMMIT;
