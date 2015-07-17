BEGIN;

-- Remove existing shipping charges 

delete from country_shipping_charge where shipping_charge_id in ( select id from shipping_charge );
delete from state_shipping_charge where shipping_charge_id in ( select id from shipping_charge );
delete from postcode_shipping_charge where shipping_charge_id in ( select id from shipping_charge );
delete from shipping_charge;

SELECT setval('shipping_charge_id_seq', 1, false);
-- ???????-???: Unknown SKU 

INSERT INTO shipping_charge (id, sku, description, charge, currency_id, flat_rate, class_id, channel_id)
   VALUES (0,'','Unknown',0.00,(SELECT id FROM currency WHERE currency='UNK'),true,
      (SELECT id FROM shipping_charge_class WHERE class='Air'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

-- 9000311-001: Standard 2 days Hong Kong

INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id) 
   VALUES ('9000311-001','Standard 2 days Hong Kong',120.00,(SELECT id FROM currency WHERE currency='HKD'),true,
      (SELECT id FROM shipping_charge_class WHERE class='Air'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Hong Kong'),(SELECT id FROM shipping_charge WHERE sku = '9000311-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

-- 9000312-001: Standard 2-3 days Rest of APAC

INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id) 
   VALUES ('9000312-001','Standard 2-3 days Remaining APAC countries',120.00,(SELECT id FROM currency WHERE currency='HKD'),true,
      (SELECT id FROM shipping_charge_class WHERE class='Air'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'China'),(SELECT id FROM shipping_charge WHERE sku = '9000312-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Japan'),(SELECT id FROM shipping_charge WHERE sku = '9000312-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'South Korea'),(SELECT id FROM shipping_charge WHERE sku = '9000312-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Malaysia'),(SELECT id FROM shipping_charge WHERE sku = '9000312-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Philippines'),(SELECT id FROM shipping_charge WHERE sku = '9000312-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Singapore'),(SELECT id FROM shipping_charge WHERE sku = '9000312-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Thailand'),(SELECT id FROM shipping_charge WHERE sku = '9000312-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Taiwan ROC'),(SELECT id FROM shipping_charge WHERE sku = '9000312-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Vietnam'),(SELECT id FROM shipping_charge WHERE sku = '9000312-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));


-- 9000314-001: Standard 2-4 days Australia

INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id) 
   VALUES ('9000314-001','Standard 2-4 days Australia',84.00,(SELECT id FROM currency WHERE currency='HKD'),true,
      (SELECT id FROM shipping_charge_class WHERE class='Air'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Australia'),(SELECT id FROM shipping_charge WHERE sku = '9000314-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));


-- 9000313-001: Standard 3-4 days NZ, India, Indonesia

INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id) 
   VALUES ('9000313-001','Standard 3-4 days NZ, India, Indonesia',240.00,(SELECT id FROM currency WHERE currency='HKD'),true,
      (SELECT id FROM shipping_charge_class WHERE class='Air'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'Indonesia'),(SELECT id FROM shipping_charge WHERE sku = '9000313-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'India'),(SELECT id FROM shipping_charge WHERE sku = '9000313-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   VALUES ((SELECT id FROM country WHERE country = 'New Zealand'),(SELECT id FROM shipping_charge WHERE sku = '9000313-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

-- 9000321-001: Global standard (3-5 days) Rest of the world
-- Add the other countries not previous covered by the other shipping sku's 

INSERT INTO shipping_charge (sku, description, charge, currency_id, flat_rate, class_id, channel_id) 
   VALUES ('9000321-001','Global standard (3-5 days) Rest of the world',240.00,(SELECT id FROM currency WHERE currency='HKD'),true,
      (SELECT id FROM shipping_charge_class WHERE class='Air'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'));

INSERT INTO country_shipping_charge (country_id, shipping_charge_id, channel_id) 
   SELECT id, (SELECT id FROM shipping_charge WHERE sku = '9000321-001'),(SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
   FROM country
     WHERE country.id NOT IN (
        SELECT country_id FROM country_shipping_charge 
        WHERE shipping_charge_id in (
           (SELECT id FROM shipping_charge WHERE sku = '9000311-001'),
           (SELECT id FROM shipping_charge WHERE sku = '9000312-001'),
           (SELECT id FROM shipping_charge WHERE sku = '9000314-001'),
           (SELECT id FROM shipping_charge WHERE sku = '9000313-001')
        )
        AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM')
     ); 

COMMIT;
