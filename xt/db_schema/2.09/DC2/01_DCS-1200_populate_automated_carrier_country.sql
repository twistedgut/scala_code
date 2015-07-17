-- Populate table 'automated_carrier_country'
-- for UPS and United States

BEGIN WORK;

INSERT INTO automated_carrier_country VALUES (
    (SELECT id FROM carrier WHERE name = 'UPS'),
    (SELECT id FROM country WHERE country = 'United States')
);

COMMIT WORK;
