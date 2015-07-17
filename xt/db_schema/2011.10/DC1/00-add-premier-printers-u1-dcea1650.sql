BEGIN;

-- Premier printers for use at labelling/dispatch in Unit 1

  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           ),
           'Premier Address Card 3 (Unit 1)',
           'u1_premiercard_03'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierShippingPrinters'
           ),
           'Premier Shipping 3 (Unit 1)',
           'u1_premiershipping_03'
         )
       ;

COMMIT;
