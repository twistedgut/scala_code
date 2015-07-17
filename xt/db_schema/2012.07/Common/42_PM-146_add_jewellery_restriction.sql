BEGIN;

INSERT INTO ship_restriction (title, code) VALUES ('Jewellery', 'JEWELLERY');

-- All Jewellery products are restricted for import into Russia
INSERT INTO ship_restriction_location (ship_restriction_id, location, type) VALUES ( (SELECT id FROM ship_restriction WHERE title = 'Jewellery'), (SELECT code FROM country WHERE country = 'Russia'), 'COUNTRY');

COMMIT;
