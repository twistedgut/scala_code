-- CANDO-8326: Add new config setting to section 'order_search' in the
--             'system_config' tables for Searching for Orders by Designer

BEGIN WORK;

INSERT INTO system_config.config_group_setting ( config_group_id, setting, value ) VALUES (
    ( SELECT id FROM system_config.config_group WHERE name = 'order_search' ),
    'by_designer_search_window',
    '63 DAYS'
)
;

COMMIT WORK;
