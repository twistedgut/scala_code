BEGIN;

-- Delete printers that are no longer in use

  DELETE
    FROM system_config.config_group_setting
   WHERE value in ( 'shippinglabel03',
                    'shippinglabel04',
                    'shippinglabel05',
                    'shippingdocument03',
                    'shippingdocument04',
                    'shippingdocument05'
                  );

-- Update printer names that are now in Unit 1

  UPDATE system_config.config_group_setting
     SET setting = 'U5 Shipping Label 1'
   WHERE value = 'shippinglabel01';

  UPDATE system_config.config_group_setting
     SET setting = 'U5 Shipping Document 1'
   WHERE value = 'shippingdocument01';

  UPDATE system_config.config_group_setting
     SET setting = 'U5 Shipping Label 2'
   WHERE value = 'shippinglabel02';

  UPDATE system_config.config_group_setting
     SET setting = 'U5 Shipping Document 2'
   WHERE value = 'shippingdocument02';

  UPDATE system_config.config_group_setting
     SET setting = 'U1 Shipping Label 6'
   WHERE value = 'shippinglabel06';

  UPDATE system_config.config_group_setting
     SET setting = 'U1 Shipping Document 6'
   WHERE value = 'shippingdocument06';

-- RENAME U5 docs

-- Define sequence for printers to be displayed on screen as it
-- gets messed up by changes

-- Shipping Documents

  UPDATE system_config.config_group_setting
     SET sequence = 1
   WHERE value = 'shippingdocument07';

  UPDATE system_config.config_group_setting
     SET sequence = 2
   WHERE value = 'shippingdocument08';

  UPDATE system_config.config_group_setting
     SET sequence = 3
   WHERE value = 'shippingdocument09';

  UPDATE system_config.config_group_setting
     SET sequence = 4
   WHERE value = 'shippingdocument10';

  UPDATE system_config.config_group_setting
     SET sequence = 5
   WHERE value = 'shippingdocument11';

  UPDATE system_config.config_group_setting
     SET sequence = 6
   WHERE value = 'shippingdocument06';

  UPDATE system_config.config_group_setting
     SET sequence = 7
   WHERE value = 'shippingdocument01';

  UPDATE system_config.config_group_setting
     SET sequence = 8
   WHERE value = 'shippingdocument02';

  UPDATE system_config.config_group_setting
     SET sequence = 9
   WHERE value = 'jc_shippingdocument01';

  UPDATE system_config.config_group_setting
     SET sequence = 10
   WHERE value = 'jc_shippingdocument02';

-- Shipping Labels

  UPDATE system_config.config_group_setting
     SET sequence = 1
   WHERE value = 'shippinglabel07';

  UPDATE system_config.config_group_setting
     SET sequence = 2
   WHERE value = 'shippinglabel08';

  UPDATE system_config.config_group_setting
     SET sequence = 3
   WHERE value = 'shippinglabel09';

  UPDATE system_config.config_group_setting
     SET sequence = 4
   WHERE value = 'shippinglabel10';

  UPDATE system_config.config_group_setting
     SET sequence = 5
   WHERE value = 'shippinglabel11';

  UPDATE system_config.config_group_setting
     SET sequence = 6
   WHERE value = 'shippinglabel06';

  UPDATE system_config.config_group_setting
     SET sequence = 7
   WHERE value = 'shippinglabel01';

  UPDATE system_config.config_group_setting
     SET sequence = 8
   WHERE value = 'shippinglabel02';

  UPDATE system_config.config_group_setting
     SET sequence = 9
   WHERE value = 'jc_shippinglabel01';

  UPDATE system_config.config_group_setting
     SET sequence = 10
   WHERE value = 'jc_shippinglabel02';

COMMIT;
