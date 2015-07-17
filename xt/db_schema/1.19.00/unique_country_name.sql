-- This patch will make country.country unique

BEGIN;

    ALTER TABLE country ADD UNIQUE(country);

COMMIT;
