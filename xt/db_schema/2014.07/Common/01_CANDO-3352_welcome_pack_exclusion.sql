-- CANDO-3352: Add a Welcome Pack exclusion
--             setting by Product Type

BEGIN WORK;

INSERT INTO system_config.config_group_setting (config_group_id,setting,value)
SELECT  grp.id,
        'exclude_on_product_type',
        'PORTER Magazine'
FROM    system_config.config_group grp
        JOIN channel ch ON ch.id = grp.channel_id
        JOIN business b ON b.id  = ch.business_id
                       AND b.config_section = 'NAP'
WHERE   grp.name = 'Welcome_Pack'
;

COMMIT WORK;
