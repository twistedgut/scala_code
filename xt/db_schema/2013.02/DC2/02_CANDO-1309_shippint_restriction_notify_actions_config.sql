-- CANDO-1309: This will turn on 'notifications' for
--             the CITES and F&W Shipping restrictions
--             instead of them being set to 'restrict'

BEGIN WORK;

UPDATE  system_config.config_group_setting
    SET value   = 'notify'
WHERE   config_group_id = (
    SELECT  id
    FROM    system_config.config_group
    WHERE   name = 'ShippingRestrictionActions'
)
AND     setting IN ('CITES','Fish & Wildlife')
;

COMMIT WORK;
