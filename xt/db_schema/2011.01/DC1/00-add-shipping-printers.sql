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
           'shippingdocument01'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'Shipping Document 2',
           'shippingdocument02'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'Shipping Document 3',
           'shippingdocument03'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'Shipping Document 4',
           'shippingdocument04'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'Shipping Document 5',
           'shippingdocument05'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingDocumentPrinters'
           ),
           'Shipping Document 6',
           'shippingdocument06'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'Shipping Label 1',
           'shippinglabel01'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'Shipping Label 2',
           'shippinglabel02'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'Shipping Label 3',
           'shippinglabel03'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'Shipping Label 4',
           'shippinglabel04'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'Shipping Label 5',
           'shippinglabel05'
         ),
         (
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'ShippingLabelPrinters'
           ),
           'Shipping Label 6',
           'shippinglabel06'
         )
       ;

COMMIT;
