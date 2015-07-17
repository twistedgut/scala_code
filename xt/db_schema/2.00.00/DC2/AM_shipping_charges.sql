
BEGIN;

select setval('shipping_charge_id_seq', (select max(id) + 1 from shipping_charge) );

-- create Outnet shipping options
INSERT INTO shipping_charge ( sku, description, charge, currency_id, flat_rate, class_id ) VALUES ( '904000-001', 'USA - Ground', 7.95, 2, true, 2);
INSERT INTO shipping_charge ( sku, description, charge, currency_id, flat_rate, class_id ) VALUES ( '904001-001', 'USA - Saver Service', 11.95, 2, true, 3);
INSERT INTO shipping_charge ( sku, description, charge, currency_id, flat_rate, class_id ) VALUES ( '904002-001', 'Canada', 24.95, 2, true, 3);
INSERT INTO shipping_charge ( sku, description, charge, currency_id, flat_rate, class_id ) VALUES ( '904003-001', 'Americas', 39.95, 2, true, 3);
INSERT INTO shipping_charge ( sku, description, charge, currency_id, flat_rate, class_id ) VALUES ( '904004-001', 'International', 55.00, 2, true, 3);


-- link SKU's to countries

-- USA
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'United States'), (SELECT id FROM shipping_charge WHERE sku = '904000-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'United States'), (SELECT id FROM shipping_charge WHERE sku = '904001-001'), 4);

-- Canada
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Canada'), (SELECT id FROM shipping_charge WHERE sku = '904002-001'), 4);

-- Americas
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Martinique'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Montserrat'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Nicaragua'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Netherlands Antilles'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Panama'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Paraguay'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Peru'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Puerto Rico'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Brazil'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Chile'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Saint Kitts and Nevis'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Saint Lucia'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Saint Vincent and the Grenadines'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Suriname'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Uruguay'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'British Virgin Islands'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'US Virgin Islands'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Bahamas'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Barbados'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'French Polynesia'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Anguilla'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Antigua and Barbuda'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Belize'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Bermuda'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Bolivia'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Argentina'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Jamaica'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Venezuela'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Cayman Islands'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Colombia'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Costa Rica'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Dominican Republic'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Ecuador'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'El Salvador'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Falkland Islands'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'French Guiana'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Grenada'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Aruba'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Guadeloupe'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Guatemala'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Guyana'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Honduras'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Dominica'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Mexico'), (SELECT id FROM shipping_charge WHERE sku = '904003-001'), 4);


-- International
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'United Kingdom'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Malta'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Ireland'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Monaco'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Netherlands'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Italy'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Poland'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Portugal'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Slovenia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Spain'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Sweden'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'United Kingdom'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Austria'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Bulgaria'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Belgium'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Lithuania'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Croatia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Cyprus'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Czech Republic'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Denmark'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Estonia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Finland'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'France'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Germany'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Greece'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Turkey'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Hungary'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Latvia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Luxembourg'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Romania'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Slovakia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Gibraltar'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Russia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Serbia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Norway'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Switzerland'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Ukraine'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Azerbaijan'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Albania'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Andorra'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Belarus'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Bosnia-Herzegovina'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Montenegro'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Faroe Islands'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Georgia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Iceland'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Canary Islands'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Liechtenstein'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Macedonia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Kazakhstan'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Moldova'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'San Marino'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Belgium'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Ireland'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Luxembourg'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Netherlands'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'France'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Germany'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Austria'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Italy'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Portugal'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Spain'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Switzerland'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Denmark'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Finland'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Norway'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Sweden'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Greece'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Romania'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Russia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Israel'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Oman'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Qatar'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Saudi Arabia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'United Arab Emirates'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Jordan'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Yemen'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Bahrain'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Kuwait'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Lebanon'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Maldives'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Mongolia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Nepal'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Pakistan'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Brunei'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Saipan'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Seychelles'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Singapore'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Japan'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Sri Lanka'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Taiwan ROC'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'China'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Vietnam'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Bangladesh'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Malaysia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Bhutan'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Philippines'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Cambodia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'South Korea'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'East Timor'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Thailand'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Guam'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Hong Kong'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'India'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Indonesia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'North Korea'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Laos'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Macau'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Papua New Guinea'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Pakistan'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Senegal'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Tunisia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Angola'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Cameroon'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'North Korea'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Liberia'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);
INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) VALUES ( (SELECT id FROM country WHERE country = 'Madagascar'), (SELECT id FROM shipping_charge WHERE sku = '904004-001'), 4);


-- create new Outnet accounts

-- Domestic UPS
INSERT INTO shipping_account VALUES ((SELECT max(id) + 1 FROM shipping_account), 'Domestic', '888888888', 2, 4);
-- International UPS
INSERT INTO shipping_account VALUES ((SELECT max(id) + 1 FROM shipping_account), 'International', '999999999', 2, 4);




COMMIT;