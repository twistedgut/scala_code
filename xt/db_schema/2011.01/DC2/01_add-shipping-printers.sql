BEGIN;

-- Printer groups

  INSERT
    INTO system_config.config_group ( name )
  VALUES ( 'ShippingDocumentPrinters' ),
         ( 'ShippingLabelPrinters'    )
       ;

-- Individual printers

  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'Shipping Document 1',
           'shipping-dc2'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'Shipping Document 2',
           'shipping-dc2'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'Shipping Label 1',
           'shippinglabel1'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'Shipping Label 2',
           'shippinglabel2'
         )
       ;

COMMIT;
