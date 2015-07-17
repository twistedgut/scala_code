
--
-- DCA-3531 - pick scheduler capacities
--
-- Add prl.identifier_name, so we have a real name to use ("dcd", not
-- "dematic")
--

BEGIN;

ALTER TABLE prl ADD COLUMN identifier_name TEXT;

UPDATE prl SET identifier_name = lower(name);
UPDATE prl SET identifier_name = 'dcd' WHERE identifier_name = 'dematic';

ALTER TABLE prl ALTER COLUMN identifier_name SET NOT NULL;

COMMIT;
