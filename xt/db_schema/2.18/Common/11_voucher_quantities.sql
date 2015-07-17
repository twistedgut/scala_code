-- Remove the existing foreign key constraint on variant_id and add a function
-- to include a check on the voucher variant table too
BEGIN;
    -- add function as fk can reference voucher.variant or public.variant
    CREATE OR REPLACE FUNCTION check_variant_id_fk()
    RETURNS TRIGGER AS $$
    BEGIN
        PERFORM id FROM public.variant WHERE id = NEW.variant_id;

        IF NOT FOUND THEN
            PERFORM id FROM voucher.variant WHERE id = NEW.variant_id;
            IF NOT FOUND THEN
                RAISE EXCEPTION '% not found in public.variant or voucher.variant table', NEW.variant_id;
            ELSE
                RETURN NEW;
            END IF;
        ELSE
            RETURN NEW;
        END IF;
    END;
    $$
    LANGUAGE 'plpgsql';

    -- Use function to check FKs in these tables
    ALTER TABLE quantity DROP CONSTRAINT new_quantity_variant_id_fkey;
    CREATE TRIGGER quantity_variant_id_fkey BEFORE INSERT OR UPDATE ON quantity FOR EACH ROW EXECUTE PROCEDURE check_variant_id_fk();

    ALTER TABLE log_stock DROP CONSTRAINT log_stock_variant_id_fkey;
    CREATE TRIGGER log_stock_variant_id_fkey BEFORE INSERT OR UPDATE ON log_stock FOR EACH ROW EXECUTE PROCEDURE check_variant_id_fk();
COMMIT;
