BEGIN;

-- field to store artibary default sort order we use in ful/dcs
ALTER TABLE public.channel ADD COLUMN idx INTEGER DEFAULT NULL;

COMMIT;
