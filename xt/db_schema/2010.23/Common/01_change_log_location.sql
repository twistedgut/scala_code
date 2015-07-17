-- Change 'log_location' to allow for normal products and voucher variants

BEGIN WORK;

ALTER TABLE log_location
    DROP CONSTRAINT log_new_location_variant_id_fkey;

CREATE INDEX new_log_location_variant_id_key ON log_location(variant_id);

CREATE TRIGGER log_location_variant_id_fkey
  BEFORE INSERT OR UPDATE
    ON log_location
      FOR EACH ROW
        EXECUTE PROCEDURE check_variant_id_fk()
;

COMMIT WORK;
