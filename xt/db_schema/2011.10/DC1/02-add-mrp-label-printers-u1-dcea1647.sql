BEGIN;

-- DCEA-1647

-- Add new MrP sticker printers to be used at selected Unit 1 pack stations
  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PackingPrinterList'
           ),
           'U1 MRP Printer 17',
           'u1_mrpsticker_pack_17'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PackingPrinterList'
           ),
           'U1 MRP Printer 18',
           'u1_mrpsticker_pack_18'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PackingPrinterList'
           ),
           'U1 MRP Printer 19',
           'u1_mrpsticker_pack_19'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PackingPrinterList'
           ),
           'U1 MRP Printer 20',
           'u1_mrpsticker_pack_20'
         );



COMMIT;
