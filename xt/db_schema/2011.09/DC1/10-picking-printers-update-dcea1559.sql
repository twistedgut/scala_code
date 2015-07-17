BEGIN;

-- Add gift message printers for pick station 0
  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = (SELECT id FROM channel WHERE name='NET-A-PORTER.COM')
           ),
           'Gift Card NAP 0',
           'u1_napgift_pick_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = (SELECT id FROM channel WHERE name='theOutnet.com')
           ),
           'Gift Card OUT 0',
           'u1_outgift_pick_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = (SELECT id FROM channel WHERE name='MRPORTER.COM')
           ),
           'Gift Card MRP 0',
           'u1_mrpgift_pick_00'
         );

-- Add mrp sticker printers for pick stations 0-16

-- First add the PickingPrinterList config group, which is already mentioned
-- in the code but doesn't exist yet

    INSERT INTO system_config.config_group (name, active) VALUES ('PickingPrinterList',true);

  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 0',
           'u1_mrpsticker_pick_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 1',
           'u1_mrpsticker_pick_01'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 2',
           'u1_mrpsticker_pick_02'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 3',
           'u1_mrpsticker_pick_03'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 4',
           'u1_mrpsticker_pick_04'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 5',
           'u1_mrpsticker_pick_05'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 6',
           'u1_mrpsticker_pick_06'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 7',
           'u1_mrpsticker_pick_07'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 8',
           'u1_mrpsticker_pick_08'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 9',
           'u1_mrpsticker_pick_09'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 10',
           'u1_mrpsticker_pick_10'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 11',
           'u1_mrpsticker_pick_11'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 12',
           'u1_mrpsticker_pick_12'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 13',
           'u1_mrpsticker_pick_13'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 14',
           'u1_mrpsticker_pick_14'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 15',
           'u1_mrpsticker_pick_15'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PickingPrinterList'
           ),
           'Picking MRP Printer 16',
           'u1_mrpsticker_pick_16'
         );

-- Add premier address card printers for pick stations 0-16

  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 0',
           'u1_premiercard_pick_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 1',
           'u1_premiercard_pick_01'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 2',
           'u1_premiercard_pick_02'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 3',
           'u1_premiercard_pick_03'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 4',
           'u1_premiercard_pick_04'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 5',
           'u1_premiercard_pick_05'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 6',
           'u1_premiercard_pick_06'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 7',
           'u1_premiercard_pick_07'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 8',
           'u1_premiercard_pick_08'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 9',
           'u1_premiercard_pick_09'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 10',
           'u1_premiercard_pick_10'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 11',
           'u1_premiercard_pick_11'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 12',
           'u1_premiercard_pick_12'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 13',
           'u1_premiercard_pick_13'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 14',
           'u1_premiercard_pick_14'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 15',
           'u1_premiercard_pick_15'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Picking Premier Address Card 16',
           'u1_premiercard_pick_16'
         )
       ;

-- Delete old premier address card printers for pick stations 3-6
    DELETE FROM system_config.config_group_setting
    WHERE config_group_id = ( SELECT id FROM system_config.config_group WHERE name = 'PremierAddressCardPrinters')
    AND setting IN ('Premier Address Card 3','Premier Address Card 4','Premier Address Card 5','Premier Address Card 6');


COMMIT;
