-- Add new country Curacao with same details as Netherlands Antilles

BEGIN;

INSERT INTO country(code,
            country,
            sub_region_id,
            proforma,
            returns_proforma,
            currency_id,
            shipping_zone_id,
            dhl_tariff_zone,
            phone_prefix,
            is_commercial_proforma,
            local_currency_code)
         VALUES('XC',
            'Curacao',
            (SELECT sub_region_id FROM country WHERE country = 'Netherlands Antilles'),
            (SELECT proforma FROM country WHERE country = 'Netherlands Antilles'),
            (SELECT returns_proforma FROM country WHERE country = 'Netherlands Antilles'),
            (SELECT currency_id FROM country WHERE country = 'Netherlands Antilles'),
            (SELECT shipping_zone_id FROM country WHERE country = 'Netherlands Antilles'),
            (SELECT dhl_tariff_zone FROM country WHERE country = 'Netherlands Antilles'),
            (SELECT phone_prefix FROM country WHERE country = 'Netherlands Antilles'),
            (SELECT is_commercial_proforma FROM country WHERE country = 'Netherlands Antilles'),
            (SELECT local_currency_code FROM country WHERE country = 'Netherlands Antilles'));

-- update shipping charge

INSERT INTO country_shipping_charge(country_id,
                                    shipping_charge_id,
                                    channel_id)
       VALUES((SELECT id FROM country WHERE country = 'Curacao'),
              (SELECT id FROM shipping_charge WHERE channel_id
                    = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
                    AND description = 'Global standard (3-5 days) Rest of the world'),
              (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

-- update shipment type

INSERT into country_shipment_type(channel_id,
                                  country_id,
                                  shipment_type_id)
       values((SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
              (SELECT id FROM country WHERE country = 'Curacao'),
              (SELECT id FROM shipment_type WHERE type = 'International DDU'));

INSERT into country_shipment_type(channel_id,
                                  country_id,
                                  shipment_type_id)
       values((SELECT id FROM channel WHERE name = 'theOutnet.com'),
              (SELECT id FROM country WHERE country = 'Curacao'),
              (SELECT id FROM shipment_type WHERE type = 'International DDU'));

INSERT into country_shipment_type(channel_id,
                                  country_id,
                                  shipment_type_id)
       values((SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
              (SELECT id FROM country WHERE country = 'Curacao'),
              (SELECT id FROM shipment_type WHERE type = 'International DDU'));

INSERT into country_shipment_type(channel_id,
                                  country_id,
                                  shipment_type_id)
       values((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'),
              (SELECT id FROM country WHERE country = 'Curacao'),
              (SELECT id FROM shipment_type WHERE type = 'International DDU'));

COMMIT;
