-- Rework the SLA intervals

BEGIN;
    -- Delete all channelised SLAs except for standard Outnet shipments (has different SLA)
    DELETE FROM system_config.config_group_setting me
        USING system_config.config_group sccg
        WHERE sccg.id = me.config_group_id
          AND sccg.name = 'dispatch_slas'
          AND me.id != (
            SELECT sccgs.id FROM system_config.config_group_setting sccgs
            JOIN system_config.config_group sccg ON sccgs.config_group_id = sccg.id
            WHERE sccg.channel_id = ( SELECT c.id FROM channel c JOIN business b on c.business_id = b.id AND b.config_section = 'OUTNET' )
            AND sccgs.setting = 'sla_standard'
        )
    ;
    -- Re-insert channel-specific SLAs as default_SLAs
    INSERT INTO system_config.config_group_setting ( config_group_id, setting, value )
        VALUES
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'default_slas' ),
            'sla_sale',
            '2 days'
        ),
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'default_slas' ),
            'sla_staff',
            '7 days'
        )
    ;
COMMIT;
