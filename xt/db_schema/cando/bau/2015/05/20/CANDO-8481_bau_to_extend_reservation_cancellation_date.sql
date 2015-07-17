
-- CANDO-8481: Updating Reservation Expiry date to be 1 year
--

BEGIN WORK;

UPDATE system_config.config_group_setting
    SET value = '1 year'
WHERE  config_group_id IN (
    SELECT  id
    FROM    system_config.config_group
    WHERE   name = 'Reservation'
)
AND setting = 'expire_pending_after'
;

COMMIT WORK;
