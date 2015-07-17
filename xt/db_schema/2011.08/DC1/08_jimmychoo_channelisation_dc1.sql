BEGIN;

INSERT INTO shipping_account VALUES (default, 'Unknown', '', 0, (select id from channel where name = 'JIMMYCHOO.COM'), 7, '', '');   
INSERT INTO shipping_account VALUES (default, 'Domestic', '138916420', 1, (select id from channel where name = 'JIMMYCHOO.COM'), 10, '', '');    
INSERT INTO shipping_account VALUES (default, 'International', '138916417', 1, (select id from channel where name = 'JIMMYCHOO.COM'), 12, '', '');


INSERT INTO shipping_charge VALUES (default, 'europe', 'Europe', 17.50, 1, true, 3);
INSERT INTO shipping_charge VALUES (default, 'londonpremierzonea' , 'Premier Zone A' , 15.00 , 1 , true , 1);
INSERT INTO shipping_charge VALUES (default, 'londonpremierzoneb' , 'Premier Zone B' , 12.00 , 1 , true , 1);
INSERT INTO shipping_charge VALUES (default, 'londonpremierzonec' , 'Premier Zone C' , 20.00 , 1 , true , 1);
INSERT INTO shipping_charge VALUES (default, 'londonpremierzoned' , 'Premier Zone D' , 25.00 , 1 , true , 1);
INSERT INTO shipping_charge VALUES (default, 'londonpremierzonee' , 'Premier Zone E' , 30.00 , 1 , true , 1);
INSERT INTO shipping_charge VALUES (default, 'londonpremierzonef' , 'Premier Zone F' , 35.00 , 1 , true , 1);
INSERT INTO shipping_charge VALUES (default, 'northamerica' , 'North America' , 12.00 , 1 , true , 3);
INSERT INTO shipping_charge VALUES (default, 'restoftheworld' , 'Rest of the World' , 25.00 , 1 , true , 3);
INSERT INTO shipping_charge VALUES (default, 'southamerica' , 'South America' , 25.00 , 1 , true , 3);
INSERT INTO shipping_charge VALUES (default, 'uklondonstandard' , 'UK/London Standard' , 11.75 , 1 , true , 3);


INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
SELECT  id,
        (SELECT id FROM shipping_charge WHERE sku = 'uklondonstandard'),
        (select id from channel where name = 'JIMMYCHOO.COM')        
FROM    country
WHERE   country IN ('United Kingdom', 'Jersey', 'Guernsey')
;

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
SELECT  id,
        (SELECT id FROM shipping_charge WHERE sku = 'europe'),
        (select id from channel where name = 'JIMMYCHOO.COM')        
FROM    country
WHERE   country IN ('Malta', 'Ireland', 'Monaco', 'Netherlands', 'Norway', 'Italy', 'Poland', 'Portugal', 'Slovenia', 'Spain', 'Sweden', 'Switzerland', 'Austria', 'Bulgaria', 'Albania', 'Andorra', 'Belgium', 'Lithuania', 'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Estonia', 'Faroe Islands', 'Finland', 'France', 'Germany', 'Greece', 'Turkey', 'Hungary', 'Latvia', 'Luxembourg', 'Romania', 'Slovakia', 'Canary Islands')
;

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
SELECT  id,
        (SELECT id FROM shipping_charge WHERE sku = 'northamerica'),
        (select id from channel where name = 'JIMMYCHOO.COM')        
FROM    country
WHERE   country IN ('Martinique', 'Montserrat', 'Nicaragua', 'Netherlands Antilles', 'Panama', 'Paraguay', 'Saint Kitts and Nevis', 'Saint Lucia', 'Saint Vincent and the Grenadines', 'Suriname', 'United States', 'Anguilla', 'Belize', 'Bolivia', 'Jamaica', 'Colombia', 'Ecuador', 'El Salvador', 'Falkland Islands', 'French Guiana', 'Grenada', 'Aruba', 'Guatemala', 'Honduras', 'Trinidad and Tobago', 'Dominica', 'Canada', 'Turks and Caicos Islands')
;
    
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id)
SELECT  id,
        (SELECT id FROM shipping_charge WHERE sku = 'restoftheworld'),
        (select id from channel where name = 'JIMMYCHOO.COM')        
FROM    country
WHERE   country IN ('Malawi', 'Russia', 'Maldives', 'Mauritius', 'Israel', 'Mongolia', 'Morocco', 'Mozambique', 'Serbia', 'Namibia', 'Nepal', 'New Caledonia', 'New Zealand', 'Oman', 'Pakistan', 'Peru', 'Brunei', 'Puerto Rico', 'Qatar', 'Lesotho', 'Brazil', 'Saipan', 'Samoa', 'Saudi Arabia', 'Senegal', 'Seychelles', 'Sierra Leone', 'Singapore', 'Japan', 'Chile', 'Sri Lanka', 'Bermuda', 'Swaziland', 'Taiwan ROC', 'Tanzania', 'China', 'Togo', 'Tonga', 'Gibraltar', 'Tunisia', 'Egypt', 'Sao Tome and Principe', 'Tuvalu', 'Ukraine', 'United Arab Emirates', 'Uruguay', 'Vanuatu', 'Jordan', 'Vietnam', 'British Virgin Islands', 'US Virgin Islands', 'Yemen', 'Australia', 'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados', 'Malaysia', 'French Polynesia', 'Algeria', 'Angola', 'Antigua and Barbuda', 'Belarus', 'Ethiopia', 'Bhutan', 'Bosnia-Herzegovina', 'Botswana', 'Philippines', 'Argentina', 'Montenegro', 'Cambodia', 'Cameroon', 'Venezuela', 'Cape Verde Islands', 'Cayman Islands', 'South Africa', 'South Korea', 'Comoros Islands', 'Cook Islands', 'Costa Rica', 'Dominican Republic', 'East Timor', 'Thailand', 'Fiji', 'Gabon', 'Gambia', 'Georgia', 'Ghana', 'Kenya', 'Greenland', 'Guadeloupe', 'Guam', 'Guyana', 'Hong Kong', 'Iceland', 'India', 'Indonesia', 'North Korea', 'Liberia', 'Kuwait', 'Laos', 'Lebanon', 'Liechtenstein', 'Macau', 'Macedonia', 'Madagascar', 'Unknown', 'Kazakhstan', 'Mexico', 'Moldova', 'Papua New Guinea', 'San Marino', 'Syria', 'St Barthelemy', 'Haiti')
;


INSERT INTO box VALUES (default, 'Unknown', 0.00, 0.00, true,0.00, 0.00, 0.00, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 1', 0.38, 0.71, true,22.50, 18.00, 10.50, 1, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 2', 1.14, 2.15, true,34.30, 27.00, 13.90, 2, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 3', 1.69, 3.95, true,41.70, 32.50, 17.50, 3, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 4', 1.78, 7.93, true,53.70, 35.00, 25.30, 4, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 5', 2.84, 15.48, true,67.80, 53.10, 25.80, 5, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 6', 0.12, 0.86, true,18.50, 11.00, 25.50, 6, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 7', 0.40, 2.41, true,35.50, 16.00, 25.50, 7, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 8', 0.92, 7.16, true,48.50, 23.00, 38.50, 8, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 9', 1.10, 11.68, true,46.50, 23.00, 65.50, 9, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 10', 0.17, 1.69, true,33.00, 21.50, 14.30, 10, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 11', 0.40, 5.35, true,59.50, 36.50, 14.80, 11, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 14', 0.86, 13.99, true,76.00, 47.00, 23.50, 14, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 15', 0.45, 3.90, true,97.50, 20.00, 12.00, 15, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));
INSERT INTO box VALUES (default, 'Outer 16', 0.00, 0.59, true,40.00, 29.50, 3.00, 16, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));


INSERT INTO inner_box VALUES (default, 'No Inner box', 1, true, null, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));




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
