-- GV-109,GV-700: Change 'log_pws_stock' to allow for normal products and voucher variants

BEGIN WORK;

ALTER TABLE log_pws_stock
    DROP CONSTRAINT log_pws_stock_variant_id_fkey;

CREATE INDEX new_log_pws_stock_variant_id_key ON log_pws_stock(variant_id);

CREATE TRIGGER log_pws_stock_variant_id_fkey
  BEFORE INSERT OR UPDATE
    ON log_pws_stock
      FOR EACH ROW
        EXECUTE PROCEDURE check_variant_id_fk()
;

COMMIT WORK;
