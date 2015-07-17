BEGIN;

-- Add Individual printers

  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 0',
           'u1_napgift_pick_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 0',
           'u1_mrpgift_pick_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 1',
           'u1_napgift_pick_01'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 1',
           'u1_mrpgift_pick_01'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 2',
           'u1_napgift_pick_02'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 2',
           'u1_mrpgift_pick_02'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 3',
           'u1_napgift_pick_03'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 3',
           'u1_mrpgift_pick_03'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 4',
           'u1_napgift_pick_04'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 4',
           'u1_mrpgift_pick_04'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 5',
           'u1_napgift_pick_05'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 5',
           'u1_mrpgift_pick_05'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 6',
           'u1_napgift_pick_06'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 6',
           'u1_mrpgift_pick_06'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 7',
           'u1_napgift_pick_07'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 7',
           'u1_mrpgift_pick_07'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 8',
           'u1_napgift_pick_08'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 8',
           'u1_mrpgift_pick_08'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 9',
           'u1_napgift_pick_09'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 9',
           'u1_mrpgift_pick_09'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 10',
           'u1_napgift_pick_10'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 10',
           'u1_mrpgift_pick_10'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 11',
           'u1_napgift_pick_11'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 11',
           'u1_mrpgift_pick_11'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 1
           ),
           'Gift Card NAP 12',
           'u1_napgift_pick_12'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = 5
           ),
           'Gift Card MRP 12',
           'u1_mrpgift_pick_12'
         )
       ;

COMMIT;
