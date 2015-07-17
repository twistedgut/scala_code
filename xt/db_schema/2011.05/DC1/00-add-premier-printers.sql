BEGIN;

-- Printer groups

  INSERT
    INTO system_config.config_group ( name )
  VALUES ( 'PremierShippingPrinters' ),
         ( 'PremierAddressCardPrinters'    )
       ;

-- Individual printers

  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierShippingPrinters'
           ),
           'Premier Shipping 1',
           'premiershipping01'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierShippingPrinters'
           ),
           'Premier Shipping 2',
           'premiershipping02'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Premier Address Card 1',
           'premiercard01'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Premier Address Card 2',
           'premiercard02'
         )
       ;

COMMIT;
