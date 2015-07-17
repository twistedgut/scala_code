-- CANDO-87: Add the time period to wait before
--           expiring Pending Reservations

BEGIN WORK;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value)
SELECT  id,
        'expire_pending_after',
        '6 months'
FROM    system_config.config_group
WHERE   name = 'Reservation'
;

COMMIT WORK;
