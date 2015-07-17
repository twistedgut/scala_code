BEGIN;

ALTER TABLE public.quantity ADD COLUMN status_id integer REFERENCES flow.status(id) DEFERRABLE;

DROP INDEX quantity_id_key;

-- work around different "quarantine" location ids between DCs

CREATE FUNCTION tmp_index_quantity() RETURNS integer AS $$
  DECLARE
    locid INTEGER;
  BEGIN
    SELECT id INTO locid FROM location WHERE location='Quarantine';
    RAISE NOTICE 'loc_id=%',locid;
    EXECUTE 'CREATE UNIQUE INDEX quantity_id_key ON public.quantity (variant_id, location_id, channel_id, status_id) WHERE location_id != ' || locid;
    RETURN locid;
  END;
$$ LANGUAGE plpgsql;

SELECT tmp_index_quantity();

DROP FUNCTION tmp_index_quantity();

COMMIT;
