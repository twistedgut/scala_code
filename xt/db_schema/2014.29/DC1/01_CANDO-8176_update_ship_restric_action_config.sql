-- CANDO-8176: Update the System Config Group 'ShippingRestrictionActions'
--             to add 'Hazmat LQ' as a 'restriction'

BEGIN WORK;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value) VALUES (
    ( SELECT id FROM system_config.config_group WHERE name = 'ShippingRestrictionActions' ),
    'HAZMAT_LQ',
    'restrict'
)
;

COMMIT WORK;
