
-- DCA-2649 - Create index on putaway_prep_container.created

BEGIN;

CREATE INDEX idx_putaway_prep_container_created ON putaway_prep_container (created);

COMMIT;
