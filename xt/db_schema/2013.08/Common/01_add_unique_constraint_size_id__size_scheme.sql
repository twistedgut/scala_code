BEGIN;

ALTER TABLE size_scheme_variant_size ADD CONSTRAINT size__size_scheme_unique UNIQUE (size_id,size_scheme_id);

COMMIT;