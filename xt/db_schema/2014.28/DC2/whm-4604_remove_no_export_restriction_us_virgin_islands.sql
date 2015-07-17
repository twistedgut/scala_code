
-- WHM-4604 Remove US Virgin Islands from the No Export shipping restriction for DC2

BEGIN;

DELETE FROM ship_restriction_location
WHERE location = (
    SELECT code FROM country WHERE country = 'US Virgin Islands'
)
AND ship_restriction_id = (
    SELECT id FROM ship_restriction WHERE title = 'Do Not Export'
)
AND type = 'COUNTRY';

COMMIT;
