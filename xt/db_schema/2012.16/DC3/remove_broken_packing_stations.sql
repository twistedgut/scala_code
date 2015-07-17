-- Remove broken packing stations in DC3 for NAP

BEGIN;
    DELETE FROM system_config.config_group_setting me
    USING (
        SELECT cgs.id FROM system_config.config_group_setting cgs
        JOIN system_config.config_group cg2 ON cgs.config_group_id = cg2.id
        LEFT JOIN system_config.config_group cg ON cgs.value = cg.name
        WHERE cgs.setting = 'packing_station'
        AND cg2.channel_id = (SELECT id FROM channel WHERE web_name = 'NAP-APAC')
        AND cg.name IS NULL
    ) packing_station
    WHERE me.id = packing_station.id;
COMMIT;
