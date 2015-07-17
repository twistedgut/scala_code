
--
-- Remove Switzerland from the fine jewelery shipping restriction
--

BEGIN;


DELETE FROM ship_restriction_location
       WHERE ship_restriction_id = (SELECT id
                                    FROM ship_restriction
                                    WHERE code = 'FINE_JEWEL')
       AND location = (SELECT code
                       FROM country
                       WHERE country = 'Switzerland');


COMMIT;
