-- CANDO-1262: Adding pdf footer notes to config

BEGIN WORK;



INSERT INTO system_config.config_group (name,channel_id) VALUES (
 'Reservation',
  (SELECT c.id
    FROM channel c
        JOIN business b on b.id = c.business_id
            AND b.config_section = 'NAP'
  )
);

INSERT INTO system_config.config_group (name,channel_id) VALUES (
 'Reservation',
  (SELECT c.id
    FROM channel c
        JOIN business b on b.id = c.business_id
            AND b.config_section = 'MRP'
  )
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (SELECT g.id
         FROM   system_config.config_group g
                JOIN channel c ON c.id = g.channel_id
                JOIN business b ON b.id = c.business_id
                                AND b.config_section = 'NAP'
         WHERE  g.name = 'Reservation'
    ),
    'upload_pdf_footer',
    'Prices are approximate and may change depending on your delivery address',
    1
);

INSERT INTO system_config.config_group_setting (config_group_id,setting,value,sequence) VALUES (
    (SELECT g.id
         FROM   system_config.config_group g
                JOIN channel c ON c.id = g.channel_id
                JOIN business b ON b.id = c.business_id
                                AND b.config_section = 'MRP'
         WHERE  g.name = 'Reservation'
    ),
    'upload_pdf_footer',
    'Prices are approximate and may change depending on your delivery address',
    1
);

COMMIT WORK;
