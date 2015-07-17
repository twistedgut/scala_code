-- CANDO-8379: Add new config setting to section 'Reservation' in the
--             'system_config' tables for 'Commission Window'

BEGIN WORK;

INSERT INTO system_config.config_group_setting (config_group_id, setting, value)
SELECT  id,
        'sale_commission_unit',
        'DAYS'
FROM    system_config.config_group
WHERE   name = 'Reservation';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value)
SELECT  id,
        'sale_commission_value',
        '21'
FROM    system_config.config_group
WHERE   name = 'Reservation';

INSERT INTO system_config.config_group_setting (config_group_id, setting, value)
SELECT  id,
        'commission_use_end_of_day',
        '1'
FROM    system_config.config_group
WHERE   name = 'Reservation';

COMMIT WORK;
