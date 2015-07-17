--
-- DCA-4322 : Amend description of "Single Grouping Wait time" in GOH System Parameters to say "(Seconds)"
--

--
-- start a transaction
--

BEGIN;

--
-- Update the description
--

UPDATE system_config.parameter SET description = 'Single Grouping Wait Time (Seconds)' WHERE name = 'deliver_within_seconds';

--
-- commit the transaction
--

COMMIT;
