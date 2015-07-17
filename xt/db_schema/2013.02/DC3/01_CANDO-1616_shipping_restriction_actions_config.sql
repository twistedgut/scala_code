-- CANDO-1616: Adding Shipping Restriction Action
--             settings in the System Config

BEGIN WORK;

-- create the group 'ShippingRestrictionActions'
INSERT INTO system_config.config_group (name)
VALUES ('ShippingRestrictionActions')
;

-- create the settings for the group
INSERT INTO system_config.config_group_setting (config_group_id, setting, value ) VALUES
(
    ( SELECT id FROM system_config.config_group WHERE name = 'ShippingRestrictionActions' ),
    'Chinese origin',
    'restrict'
),
(
    ( SELECT id FROM system_config.config_group WHERE name = 'ShippingRestrictionActions' ),
    'CITES',
    'restrict'
),
(
    ( SELECT id FROM system_config.config_group WHERE name = 'ShippingRestrictionActions' ),
    'Fish & Wildlife',
    'notify'
)
;

COMMIT WORK;
