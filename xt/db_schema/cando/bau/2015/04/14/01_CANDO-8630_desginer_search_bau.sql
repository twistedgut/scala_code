
-- CANDO-8630: Updating Search Results to be 6 months (roughly 816 days) for Desginer Search
--

BEGIN WORK;

UPDATE  system_config.config_group_setting
    SET value = '186 DAYS'
WHERE   config_group_id IN (
    SELECT  id
    FROM    system_config.config_group
    WHERE   name = 'order_search'
)
AND     setting = 'by_designer_search_window'
;

COMMIT WORK;
