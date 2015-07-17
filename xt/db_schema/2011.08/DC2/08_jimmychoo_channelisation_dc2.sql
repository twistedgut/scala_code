BEGIN;

INSERT INTO shipping_account VALUES (default, 'Unknown', '', 0, (select id from channel where name = 'JIMMYCHOO.COM'), 14, '', '');      
INSERT INTO shipping_account VALUES (default, 'Domestic', '?????????', 2, (select id from channel where name = 'JIMMYCHOO.COM'), 17, '?????????', '?????????');      
INSERT INTO shipping_account VALUES (default, 'International', '?????????', 1, (select id from channel where name = 'JIMMYCHOO.COM'), 17, '?????????', '?????????');


INSERT INTO shipping_charge VALUES (default, 'testing', 'Testing', 10.00, 1, true, 3);

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
SELECT  id,
        (SELECT id FROM shipping_charge WHERE sku = 'testing'),
        (select id from channel where name = 'JIMMYCHOO.COM')        
FROM    country
;

INSERT INTO box VALUES (default, 'Unknown', 0.00, 0.00, true,0.00, 0.00, 0.00, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));  
INSERT INTO box VALUES (default, 'Outer 1', 1.00, 0.92, true,9.56, 7.62, 4.00, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 2', 2.00, 2.18, true,13.87, 10.87, 5.50, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 3', 3.00, 3.97, true,16.37, 13.12, 6.62, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 4', 4.00, 8.25, true,21.37, 13.81, 9.87, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 5', 6.00, 15.62, true,26.75, 20.50, 10.31, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 6', 0.12, 0.86, true,0.00, 0.00, 0.00, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 7', 0.40, 2.41, true,0.00, 0.00, 0.00, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 8', 0.92, 7.16, true,0.00, 0.00, 0.00, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 9', 1.10, 11.68, true,0.00, 0.00, 0.00, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 10', 1.00, 1.69, true,13.18, 8.62, 5.80, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 11', 1.00, 5.35, true,23.25, 14.50, 6.00, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 14', 0.86, 13.99, true,76.00, 47.00, 23.50, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 15', 0.36, 2.10, true,11.00, 11.00, 112.00, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')); 
INSERT INTO box VALUES (default, 'Outer 16', 0.00, 1.30, true,15.75, 11.61, 1.18, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));


INSERT INTO inner_box VALUES (default, 'No Inner box', 1, true, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));


INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 1' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Worldwide Express Saver', 2.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 1' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Next Day Air Saver', 2.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 2' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Worldwide Express Saver', 6.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 2' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Next Day Air Saver', 4.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 3' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Worldwide Express Saver', 9.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 3' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Next Day Air Saver', 6.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 3' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Ground', 6.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 4' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Worldwide Express Saver', 18.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 4' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Next Day Air Saver', 13.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 4' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Ground', 13.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 5' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Worldwide Express Saver', 34.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 5' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Next Day Air Saver', 25.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 5' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Ground', 25.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 10' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Worldwide Express Saver', 4.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 10' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Next Day Air Saver', 3.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 11' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Worldwide Express Saver', 12.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 11' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Next Day Air Saver', 9.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 11' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Ground', 9.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 16' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Worldwide Express Saver', 2.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 16' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Next Day Air Saver', 2.00);
INSERT INTO carrier_box_weight VALUES (default, 2, (SELECT id FROM box WHERE box = 'Outer 16' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')), (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 'Ground', 2.00);




INSERT INTO system_config.config_group VALUES (default, 'Welcome_Pack', (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), false);

INSERT INTO system_config.config_group VALUES (default, 'personalized_stickers', (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), false);

INSERT INTO system_config.config_group VALUES (default, 'dispatch_slas', (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), true);

INSERT INTO system_config.config_group_setting VALUES (
  default, 
  (SELECT id FROM system_config.config_group WHERE name = 'dispatch_slas' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM') ),
  'sla_standard',
  '1 day',
  0,
  true
);

INSERT INTO system_config.config_group_setting VALUES (
  default, 
  (SELECT id FROM system_config.config_group WHERE name = 'dispatch_slas' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM') ),
  'sla_sale',
  '2 days',
  0,
  true
);

INSERT INTO system_config.config_group_setting VALUES (
  default, 
  (SELECT id FROM system_config.config_group WHERE name = 'dispatch_slas' AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM') ),
  'sla_premier',
  '1 hour',
  0,
  true
);



COMMIT;
