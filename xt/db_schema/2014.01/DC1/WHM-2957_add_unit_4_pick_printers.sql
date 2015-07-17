-- Add new unit 4 picking printers for DC1

BEGIN;
    -- Make sure the sequence is at the right place
    SELECT setval(
        'system_config.config_group_setting_id_seq',
        (SELECT MAX(id) FROM system_config.config_group_setting)
    );

    -- Add the picking printers
    INSERT INTO system_config.config_group_setting
        ( config_group_id, setting, value )
    VALUES
        -- Pick Station 40
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PremierAddressCardPrinters' ),
            'Picking Premier Address Card 40',
            'u4_premiercard_pick_40'
        ),
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PickingPrinterList' ),
            'Picking MRP Printer 40',
            'u4_mrpsticker_pick_40'
        ),
        (
            (
                SELECT id FROM system_config.config_group
                WHERE name = 'GiftCardPrinters'
                AND channel_id = ( SELECT id FROM channel where name = 'NET-A-PORTER.COM' )
            ),
            'Gift Card NAP 40',
            'u4_napgift_pick_40'
        ),
        (
            (
                SELECT id FROM system_config.config_group
                WHERE name = 'GiftCardPrinters'
                AND channel_id = ( SELECT id FROM channel where name = 'MRPORTER.COM' )
            ),
            'Gift Card MRP 40',
            'u4_mrpgift_pick_40'
        ),
        -- Pick Station 41
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PremierAddressCardPrinters' ),
            'Picking Premier Address Card 41',
            'u4_premiercard_pick_41'
        ),
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PickingPrinterList' ),
            'Picking MRP Printer 41',
            'u4_mrpsticker_pick_41'
        ),
        (
            (
                SELECT id FROM system_config.config_group
                WHERE name = 'GiftCardPrinters'
                AND channel_id = ( SELECT id FROM channel where name = 'NET-A-PORTER.COM' )
            ),
            'Gift Card NAP 41',
            'u4_napgift_pick_41'
        ),
        (
            (
                SELECT id FROM system_config.config_group
                WHERE name = 'GiftCardPrinters'
                AND channel_id = ( SELECT id FROM channel where name = 'MRPORTER.COM' )
            ),
            'Gift Card MRP 41',
            'u4_mrpgift_pick_41'
        ),
        -- Pick Station 42
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PremierAddressCardPrinters' ),
            'Picking Premier Address Card 42',
            'u4_premiercard_pick_42'
        ),
        (
            ( SELECT id FROM system_config.config_group WHERE name = 'PickingPrinterList' ),
            'Picking MRP Printer 42',
            'u4_mrpsticker_pick_42'
        ),
        (
            (
                SELECT id FROM system_config.config_group
                WHERE name = 'GiftCardPrinters'
                AND channel_id = ( SELECT id FROM channel where name = 'NET-A-PORTER.COM' )
            ),
            'Gift Card NAP 42',
            'u4_napgift_pick_42'
        ),
        (
            (
                SELECT id FROM system_config.config_group
                WHERE name = 'GiftCardPrinters'
                AND channel_id = ( SELECT id FROM channel where name = 'MRPORTER.COM' )
            ),
            'Gift Card MRP 42',
            'u4_mrpgift_pick_42'
        )
    ;

COMMIT;
