-- DCA-45: rename putaway_prep table to putaway_prep_container,
-- to make it clearer that it represents a container,
-- and to discourage it from becoming a utility class

BEGIN;

ALTER TABLE putaway_prep RENAME TO putaway_prep_container;

COMMIT;
