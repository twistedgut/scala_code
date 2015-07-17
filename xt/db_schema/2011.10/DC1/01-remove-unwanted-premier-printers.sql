BEGIN;

-- Premier printers for picking got added separately, and these haven't been
-- set up or used anywhere, so I'm removing them to try and avoid confusion

    DELETE FROM system_config.config_group_setting 
    WHERE config_group_id = 
           ( SELECT id
               FROM system_config.config_group
              WHERE name = 'PremierAddressCardPrinters'
           )
    AND setting IN ('Premier Address Card 3', 'Premier Address Card 4','Premier Address Card 5','Premier Address Card 6')
       ;

COMMIT;
