-- WHM-29 WHM-43

BEGIN;

-- Delete Gift Card printers from picking stations, because we're not
-- going to be printing those at picking for a while.

    DELETE FROM system_config.config_group_setting 
    WHERE config_group_id in 
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'GiftCardPrinters'
           )
    AND setting LIKE 'Gift Card%'
       ;

COMMIT;
