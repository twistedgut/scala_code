-- Location_id is hard-coded as partial index predicates don't support subqueries (i.e. can't do SELECT id FROM location WHERE location='Quarantine')
BEGIN;
    CREATE UNIQUE INDEX quantity_id_key ON quantity (variant_id,location_id,channel_id) WHERE location_id != 2;
COMMIT;
