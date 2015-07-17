-- CANDO-3431: Adds new System Config Section 'Customer' along with
--             setting 'no_shipping_cost_recalc_customer_category_class'

BEGIN WORK;

-- create the new 'Customer' group per Sales Channel
INSERT INTO system_config.config_group (name,channel_id)
SELECT  'Customer',
        id
FROM    channel
;

-- add the Settings for the Groups except for Jimmy Choo
INSERT INTO system_config.config_group_setting (config_group_id,setting,value)
SELECT  grp.id,
        'no_shipping_cost_recalc_customer_category_class',
        'EIP'
FROM    system_config.config_group grp
            JOIN channel ch ON ch.id = grp.channel_id
            JOIN business b ON  b.id = ch.business_id
                           AND  b.config_section != 'JC'
WHERE   grp.name = 'Customer'
;

COMMIT WORK;
