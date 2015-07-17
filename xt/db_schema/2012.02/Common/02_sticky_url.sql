-- Add a URL for sticky page redirects

BEGIN;
    ALTER TABLE operator.sticky_page ADD COLUMN sticky_url VARCHAR(255);
COMMIT;
