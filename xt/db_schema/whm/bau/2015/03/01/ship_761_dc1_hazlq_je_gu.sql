--
-- Add Hazmat LQ shipping restriction for Jersey and Guernsey
--

BEGIN;

INSERT INTO ship_restriction_location(ship_restriction_id,
                                      location,
                                      type)
VALUES((SELECT id
       FROM ship_restriction
       WHERE code = 'HZMT_LQ'),
       (SELECT code
       FROM country
       WHERE country = 'Guernsey'),
       'COUNTRY'),
       ((SELECT id
       FROM ship_restriction
       WHERE code = 'HZMT_LQ'),
       (SELECT code
       FROM country
       WHERE country = 'Jersey'),
       'COUNTRY');

COMMIT;

