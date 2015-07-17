-- XTR-872
--
--  http://jira:8080/browse/XTR-872
--  "Promotion Title needs to be increased to 60 (from 50) characters"
BEGIN;
    ALTER TABLE promotion.detail ALTER COLUMN title TYPE varchar(60);
COMMIT;
