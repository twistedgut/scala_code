BEGIN;

-- DCEA-1560

-- Add gift message printers for Unit 1 Packing Exception and Supervisor desks
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
           'U1 Packing Exception Gift Card NAP',
           'u1_napgift_pe_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = (SELECT id FROM channel WHERE name='NET-A-PORTER.COM')
           ),
           'U1 Supervisor Gift Card NAP',
           'u1_napgift_sup_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = (SELECT id FROM channel WHERE name='MRPORTER.COM')
           ),
           'U1 Packing Exception Gift Card MRP',
           'u1_mrpgift_pe_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
              AND channel_id = (SELECT id FROM channel WHERE name='MRPORTER.COM')
           ),
           'U1 Supervisor Gift Card MRP',
           'u1_mrpgift_sup_00'
         );

-- Add MrP sticker printers for Unit 1 Packing Exception and Supervisor desks
  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PackingPrinterList'
           ),
           'U1 Packing Exception MRP Label Printer',
           'u1_mrpsticker_pe_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PackingPrinterList'
           ),
           'U1 Supervisor MRP Label Printer',
           'u1_mrpsticker_sup_00'
         );

-- Add premier address card printers for Unit 1 Packing Exception and Supervisor desks
  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'U1 Packing Exception Premier Address Card',
           'u1_premiercard_pe_00'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'U1 Supervisor Premier Address Card',
           'u1_premiercard_sup_00'
         )
       ;


COMMIT;
