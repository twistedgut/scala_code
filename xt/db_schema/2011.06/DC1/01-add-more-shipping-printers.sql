BEGIN;

-- New shipping printers

  INSERT
    INTO system_config.config_group_setting (
           config_group_id, setting, value
         )
  VALUES (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'U1 Shipping Document 1',
           'shippingdocument07'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'U1 Shipping Document 2',
           'shippingdocument08'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'U1 Shipping Document 3',
           'shippingdocument09'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'U1 Shipping Document 4',
           'shippingdocument10'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'U1 Shipping Document 5',
           'shippingdocument11'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'U1 Shipping Label 1',
           'shippinglabel07'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'U1 Shipping Label 2',
           'shippinglabel08'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'U1 Shipping Label 3',
           'shippinglabel09'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'U1 Shipping Label 4',
           'shippinglabel10'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'U1 Shipping Label 5',
           'shippinglabel11'
         )
       ;

COMMIT;
