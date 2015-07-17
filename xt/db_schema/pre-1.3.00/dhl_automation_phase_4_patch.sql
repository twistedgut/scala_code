-- Purpose:
--  Create/Amend tables for reporting on DHL tariffs

BEGIN;


-- add new field(s) to country table
ALTER TABLE country ADD COLUMN dhl_tariff_zone varchar(3) null;


-- populate new column

update country set dhl_tariff_zone = '9' where country  = 'Afghanistan';
update country set dhl_tariff_zone = '9' where country  = 'Albania';
update country set dhl_tariff_zone = '9' where country  = 'Algeria';
update country set dhl_tariff_zone = '9' where country  = 'American Samoa';
update country set dhl_tariff_zone = '4' where country  = 'Andorra';
update country set dhl_tariff_zone = '9' where country  = 'Angola';
update country set dhl_tariff_zone = '9' where country  = 'Anguilla';
update country set dhl_tariff_zone = '9' where country  = 'Antigua and Barbuda';
update country set dhl_tariff_zone = '9' where country  = 'Argentina';
update country set dhl_tariff_zone = '8' where country  = 'Armenia';
update country set dhl_tariff_zone = '9' where country  = 'Aruba';
update country set dhl_tariff_zone = '7' where country  = 'Australia';
update country set dhl_tariff_zone = '3' where country  = 'Austria';
update country set dhl_tariff_zone = '8' where country  = 'Azerbaijan';
update country set dhl_tariff_zone = '9' where country  = 'Bahamas';
update country set dhl_tariff_zone = '8' where country  = 'Bahrain';
update country set dhl_tariff_zone = '9' where country  = 'Bangladesh';
update country set dhl_tariff_zone = '9' where country  = 'Barbados';
update country set dhl_tariff_zone = '8' where country  = 'Belarus';
update country set dhl_tariff_zone = '1' where country  = 'Belgium';
update country set dhl_tariff_zone = '9' where country  = 'Belize';
update country set dhl_tariff_zone = '9' where country  = 'Benin';
update country set dhl_tariff_zone = '9' where country  = 'Bermuda';
update country set dhl_tariff_zone = '9' where country  = 'Bhutan';
update country set dhl_tariff_zone = '9' where country  = 'Bolivia';
update country set dhl_tariff_zone = '9' where country  = 'Bonaire';
update country set dhl_tariff_zone = '8' where country  = 'Bosnia-Herzegovina';
update country set dhl_tariff_zone = '9' where country  = 'Botswana';
update country set dhl_tariff_zone = '9' where country  = 'Brazil';
update country set dhl_tariff_zone = '8' where country  = 'Brunei';
update country set dhl_tariff_zone = '6' where country  = 'Bulgaria';
update country set dhl_tariff_zone = '9' where country  = 'Burkino Faso';
update country set dhl_tariff_zone = '9' where country  = 'Burundi';
update country set dhl_tariff_zone = '8' where country  = 'Cambodia';
update country set dhl_tariff_zone = '9' where country  = 'Cameroon';
update country set dhl_tariff_zone = '6' where country  = 'Canada';
update country set dhl_tariff_zone = '6' where country  = 'Canary Islands';
update country set dhl_tariff_zone = '9' where country  = 'Cape Verde Islands';
update country set dhl_tariff_zone = '9' where country  = 'Cayman Islands';
update country set dhl_tariff_zone = '9' where country  = 'Central African Rep.';
update country set dhl_tariff_zone = '9' where country  = 'Chad';
update country set dhl_tariff_zone = '1' where country  = 'Channel Islands';
update country set dhl_tariff_zone = '9' where country  = 'Chile';
update country set dhl_tariff_zone = '7' where country  = 'China';
update country set dhl_tariff_zone = '9' where country  = 'Colombia';
update country set dhl_tariff_zone = '9' where country  = 'Comoros Islands';
update country set dhl_tariff_zone = '9' where country  = 'Cook Islands';
update country set dhl_tariff_zone = '9' where country  = 'Costa Rica';
update country set dhl_tariff_zone = '8' where country  = 'Croatia';
update country set dhl_tariff_zone = '9' where country  = 'Cuba';
update country set dhl_tariff_zone = '9' where country  = 'Curacao';
update country set dhl_tariff_zone = '4' where country  = 'Cyprus';
update country set dhl_tariff_zone = '4' where country  = 'Czech Republic';
update country set dhl_tariff_zone = '3' where country  = 'Denmark';
update country set dhl_tariff_zone = '9' where country  = 'DjIbouti';
update country set dhl_tariff_zone = '9' where country  = 'Dominican Republic';
update country set dhl_tariff_zone = '9' where country  = 'East Timor';
update country set dhl_tariff_zone = '9' where country  = 'Ecuador';
update country set dhl_tariff_zone = '9' where country  = 'Egypt';
update country set dhl_tariff_zone = '9' where country  = 'El Salvador';
update country set dhl_tariff_zone = '9' where country  = 'Equatorial Guinea';
update country set dhl_tariff_zone = '9' where country  = 'Eritrea';
update country set dhl_tariff_zone = '4' where country  = 'Estonia';
update country set dhl_tariff_zone = '9' where country  = 'Ethopia';
update country set dhl_tariff_zone = '9' where country  = 'Falkland Islands';
update country set dhl_tariff_zone = '9' where country  = 'Faroe Islands';
update country set dhl_tariff_zone = '9' where country  = 'Fiji';
update country set dhl_tariff_zone = '3' where country  = 'Finland';
update country set dhl_tariff_zone = '1' where country  = 'France';
update country set dhl_tariff_zone = '9' where country  = 'French Guiana';
update country set dhl_tariff_zone = '9' where country  = 'Gabon';
update country set dhl_tariff_zone = '9' where country  = 'Gambia';
update country set dhl_tariff_zone = '8' where country  = 'Georgia';
update country set dhl_tariff_zone = '1' where country  = 'Germany';
update country set dhl_tariff_zone = '9' where country  = 'Ghana';
update country set dhl_tariff_zone = '6' where country  = 'Gibraltar';
update country set dhl_tariff_zone = '3' where country  = 'Greece';
update country set dhl_tariff_zone = '9' where country  = 'Greenland';
update country set dhl_tariff_zone = '9' where country  = 'Grenada';
update country set dhl_tariff_zone = '9' where country  = 'Guadeloupe';
update country set dhl_tariff_zone = '9' where country  = 'Guam';
update country set dhl_tariff_zone = '9' where country  = 'Guatemala';
update country set dhl_tariff_zone = '9' where country  = 'Guinea Rep.';
update country set dhl_tariff_zone = '9' where country  = 'Guinea-Bissau';
update country set dhl_tariff_zone = '9' where country  = 'Guyana';
update country set dhl_tariff_zone = '9' where country  = 'Haiti';
update country set dhl_tariff_zone = '9' where country  = 'Honduras';
update country set dhl_tariff_zone = '7' where country  = 'Hong Kong';
update country set dhl_tariff_zone = '4' where country  = 'Hungary';
update country set dhl_tariff_zone = '7' where country  = 'Iceland';
update country set dhl_tariff_zone = '8' where country  = 'India';
update country set dhl_tariff_zone = '7' where country  = 'Indonesia';
update country set dhl_tariff_zone = '9' where country  = 'Iran';
update country set dhl_tariff_zone = '9' where country  = 'Iraq';
update country set dhl_tariff_zone = '1' where country  = 'Ireland';
update country set dhl_tariff_zone = '9' where country  = 'Israel';
update country set dhl_tariff_zone = '3' where country  = 'Italy';
update country set dhl_tariff_zone = '9' where country  = 'Ivory Coast';
update country set dhl_tariff_zone = '9' where country  = 'Jamaica';
update country set dhl_tariff_zone = '7' where country  = 'Japan';
update country set dhl_tariff_zone = '8' where country  = 'Jordan';
update country set dhl_tariff_zone = '8' where country  = 'Kazakhstan';
update country set dhl_tariff_zone = '9' where country  = 'Kenya';
update country set dhl_tariff_zone = '9' where country  = 'Kiribati';
update country set dhl_tariff_zone = '9' where country  = 'North Korea';
update country set dhl_tariff_zone = '7' where country  = 'South Korea';
update country set dhl_tariff_zone = '8' where country  = 'Kuwait';
update country set dhl_tariff_zone = '8' where country  = 'Kyrghyzstan';
update country set dhl_tariff_zone = '9' where country  = 'Laos';
update country set dhl_tariff_zone = '4' where country  = 'Latvia';
update country set dhl_tariff_zone = '9' where country  = 'Lebanon';
update country set dhl_tariff_zone = '9' where country  = 'Lesotho';
update country set dhl_tariff_zone = '9' where country  = 'Liberia';
update country set dhl_tariff_zone = '9' where country  = 'Libya';
update country set dhl_tariff_zone = '6' where country  = 'Liechtenstein';
update country set dhl_tariff_zone = '4' where country  = 'Lithuania';
update country set dhl_tariff_zone = '1' where country  = 'Luxembourg';
update country set dhl_tariff_zone = '7' where country  = 'Macau';
update country set dhl_tariff_zone = '9' where country  = 'Macedonia';
update country set dhl_tariff_zone = '9' where country  = 'Madagascar';
update country set dhl_tariff_zone = '9' where country  = 'Malawi';
update country set dhl_tariff_zone = '7' where country  = 'Malaysia';
update country set dhl_tariff_zone = '9' where country  = 'Maldives';
update country set dhl_tariff_zone = '9' where country  = 'Mali';
update country set dhl_tariff_zone = '4' where country  = 'Malta';
update country set dhl_tariff_zone = '9' where country  = 'Marshall Islands';
update country set dhl_tariff_zone = '9' where country  = 'Martinique';
update country set dhl_tariff_zone = '9' where country  = 'Mauritania';
update country set dhl_tariff_zone = '9' where country  = 'Mauritius';
update country set dhl_tariff_zone = '6' where country  = 'Mexico';
update country set dhl_tariff_zone = '8' where country  = 'Moldova';
update country set dhl_tariff_zone = '4' where country  = 'Monaco';
update country set dhl_tariff_zone = '9' where country  = 'Mongolia';
update country set dhl_tariff_zone = '9' where country  = 'Montserrat';
update country set dhl_tariff_zone = '9' where country  = 'Morocco';
update country set dhl_tariff_zone = '9' where country  = 'Mozambique';
update country set dhl_tariff_zone = '9' where country  = 'Myanmar (Burma)';
update country set dhl_tariff_zone = '9' where country  = 'Namibia';
update country set dhl_tariff_zone = '9' where country  = '"Nauru, Rep of"';
update country set dhl_tariff_zone = '9' where country  = 'Nepal';
update country set dhl_tariff_zone = '1' where country  = 'Netherlands';
update country set dhl_tariff_zone = '9' where country  = 'Nevis';
update country set dhl_tariff_zone = '9' where country  = 'New Caledonia';
update country set dhl_tariff_zone = '8' where country  = 'New Zealand';
update country set dhl_tariff_zone = '9' where country  = 'Nicaragua';
update country set dhl_tariff_zone = '9' where country  = 'Niger';
update country set dhl_tariff_zone = '9' where country  = 'Nigeria';
update country set dhl_tariff_zone = '9' where country  = 'Niue';
update country set dhl_tariff_zone = '6' where country  = 'Norway';
update country set dhl_tariff_zone = '8' where country  = 'Oman';
update country set dhl_tariff_zone = '9' where country  = 'Pakistan';
update country set dhl_tariff_zone = '9' where country  = 'Panama';
update country set dhl_tariff_zone = '8' where country  = 'Papua New Guinea';
update country set dhl_tariff_zone = '9' where country  = 'Paraguay';
update country set dhl_tariff_zone = '9' where country  = 'Peru';
update country set dhl_tariff_zone = '7' where country  = 'Philippines';
update country set dhl_tariff_zone = '4' where country  = 'Poland';
update country set dhl_tariff_zone = '3' where country  = 'Portugal';
update country set dhl_tariff_zone = '9' where country  = 'Puerto Rico';
update country set dhl_tariff_zone = '8' where country  = 'Qatar';
update country set dhl_tariff_zone = '9' where country  = 'Reunion Island';
update country set dhl_tariff_zone = '6' where country  = 'Romania';
update country set dhl_tariff_zone = '7' where country  = 'Russia';
update country set dhl_tariff_zone = '9' where country  = 'Rwanda';
update country set dhl_tariff_zone = '9' where country  = 'Saipan';
update country set dhl_tariff_zone = '9' where country  = 'Samoa';
update country set dhl_tariff_zone = '9' where country  = 'Sao Tome & Principe';
update country set dhl_tariff_zone = '8' where country  = 'Saudi Arabia';
update country set dhl_tariff_zone = '9' where country  = 'Senegal';
update country set dhl_tariff_zone = '9' where country  = 'Serbia and Montenegro';
update country set dhl_tariff_zone = '9' where country  = 'Seychelles';
update country set dhl_tariff_zone = '9' where country  = 'Sierra Leone';
update country set dhl_tariff_zone = '7' where country  = 'Singapore';
update country set dhl_tariff_zone = '4' where country  = 'Slovakia';
update country set dhl_tariff_zone = '4' where country  = 'Slovenia';
update country set dhl_tariff_zone = '8' where country  = 'Solomon Islands';
update country set dhl_tariff_zone = '9' where country  = 'Somalia';
update country set dhl_tariff_zone = '9' where country  = 'Somaliland Rep. Of';
update country set dhl_tariff_zone = '8' where country  = 'South Africa';
update country set dhl_tariff_zone = '3' where country  = 'Spain';
update country set dhl_tariff_zone = '9' where country  = 'Sri Lanka';
update country set dhl_tariff_zone = '9' where country  = 'St. Barthelemy';
update country set dhl_tariff_zone = '9' where country  = 'St Eustatius';
update country set dhl_tariff_zone = '9' where country  = 'Saint Kitts and Nevis';
update country set dhl_tariff_zone = '9' where country  = 'Saint Lucia';
update country set dhl_tariff_zone = '9' where country  = 'St Maarten';
update country set dhl_tariff_zone = '9' where country  = 'Saint Vincent and the Grenadines';
update country set dhl_tariff_zone = '9' where country  = 'Sudan';
update country set dhl_tariff_zone = '9' where country  = 'Suriname';
update country set dhl_tariff_zone = '9' where country  = 'Swaziland';
update country set dhl_tariff_zone = '3' where country  = 'Sweden';
update country set dhl_tariff_zone = '6' where country  = 'Switzerland';
update country set dhl_tariff_zone = '9' where country  = 'Syria';
update country set dhl_tariff_zone = '9' where country  = 'Tahiti';
update country set dhl_tariff_zone = '7' where country  = 'Taiwan ROC';
update country set dhl_tariff_zone = '8' where country  = 'Tajikistan';
update country set dhl_tariff_zone = '9' where country  = 'Tanzania';
update country set dhl_tariff_zone = '7' where country  = 'Thailand';
update country set dhl_tariff_zone = '9' where country  = 'Togo';
update country set dhl_tariff_zone = '9' where country  = 'Tonga';
update country set dhl_tariff_zone = '9' where country  = 'Trinidad & Tobago';
update country set dhl_tariff_zone = '9' where country  = 'Tunisia';
update country set dhl_tariff_zone = '6' where country  = 'Turkey';
update country set dhl_tariff_zone = '8' where country  = 'Turkmenistan';
update country set dhl_tariff_zone = '9' where country  = 'Turks & Caicos Islands';
update country set dhl_tariff_zone = '9' where country  = 'Tuvalu';
update country set dhl_tariff_zone = '9' where country  = 'Uganda';
update country set dhl_tariff_zone = '6' where country  = 'Ukraine';
update country set dhl_tariff_zone = '8' where country  = 'United Arab Emirates';
update country set dhl_tariff_zone = 'DOM' where country  = 'United Kingdom';
update country set dhl_tariff_zone = '9' where country  = 'Uruguay';
update country set dhl_tariff_zone = '5' where country  = 'United States';
update country set dhl_tariff_zone = '8' where country  = 'Uzbekistan';
update country set dhl_tariff_zone = '9' where country  = 'Vanuatu';
update country set dhl_tariff_zone = '9' where country  = 'Venezuela';
update country set dhl_tariff_zone = '7' where country  = 'Vietnam';
update country set dhl_tariff_zone = '9' where country  = 'British Virgin Islands';
update country set dhl_tariff_zone = '9' where country  = 'U.S. Virgin Islands';
update country set dhl_tariff_zone = '8' where country  = 'Yemen';
update country set dhl_tariff_zone = '9' where country  = 'Zambia';
update country set dhl_tariff_zone = '9' where country  = 'Zimbabwe';

-- Create table to store outbound tariffs
create table dhl_outbound_tariff (
	tariff_zone varchar(3) NOT NULL,
	weight numeric(10,2) NOT NULL,
	tariff numeric(10,2) NOT NULL,
	constraint pk_tariff_weight primary key (tariff_zone, weight)
	);

grant all on dhl_outbound_tariff to www;

-- Create table to store inbound tariffs
create table dhl_inbound_tariff (
	tariff_zone varchar(3) NOT NULL,
	weight numeric(10,2) NOT NULL,
	tariff numeric(10,2) NOT NULL,
	constraint pk_ret_tariff_weight primary key (tariff_zone, weight)
	);

grant all on dhl_inbound_tariff to www;

-- Do it!
COMMIT;
