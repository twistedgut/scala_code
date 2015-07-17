-- We have a three-state boolean here, which is weird... we have to do things
-- like do_not_use IS NOT TRUE to check for false. Crazy shit. Anyway, let's
-- make this a boolean with a default of 'false', so our aptly named do_not_use
-- column isn't true by default. Not much of an improvement, but it does help a
-- little.
BEGIN;
    UPDATE sample_receiver SET do_not_use = false WHERE do_not_use IS NULL;
    ALTER TABLE sample_receiver ALTER do_not_use SET DEFAULT false, ALTER COLUMN do_not_use SET NOT NULL;
COMMIT;
