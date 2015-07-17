--
-- CANDO-1870
--
-- Brazil is always DDU from DC3 for now

BEGIN WORK;

UPDATE country_shipment_type
   SET shipment_type_id = (
           SELECT id
             FROM shipment_type
            WHERE type = 'International DDU'
       )
 WHERE country_id = (
           SELECT id
             FROM country
            WHERE country = 'Brazil'
       )
     ;

COMMIT WORK;
