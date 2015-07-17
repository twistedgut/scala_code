--
-- CANDO-1868
--
-- Disable No_Delivery_Signature_Credit_Hold_Threshold for DC3
--

BEGIN WORK;

DELETE
  FROM system_config.config_group_setting
 WHERE config_group_id IN (
         SELECT id
           FROM system_config.config_group
          WHERE name = 'No_Delivery_Signature_Credit_Hold_Threshold'
     )
     ;

DELETE
  FROM system_config.config_group
 WHERE name = 'No_Delivery_Signature_Credit_Hold_Threshold'
     ;

COMMIT WORK;
