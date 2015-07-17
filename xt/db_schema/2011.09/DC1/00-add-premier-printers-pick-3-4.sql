BEGIN;

-- Premier address card printers for pick stations 3 and 4

  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Premier Address Card 3',
           'premiercard03'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Premier Address Card 4',
           'premiercard04'
         )
       ;

COMMIT;
