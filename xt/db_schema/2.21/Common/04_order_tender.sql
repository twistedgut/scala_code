BEGIN;

-- In order to be able to backfill the orders.tender table before the release
-- date, this part of the patch has been commented out and will be run prior
-- to the release.
-- CREATE TABLE orders.tender (
--     id serial PRIMARY KEY,
--     order_id integer REFERENCES orders(id) DEFERRABLE NOT NULL,
--     voucher_code_id integer REFERENCES voucher.code(id) DEFERRABLE,
--     rank integer NOT NULL,
--     value numeric(10,3) NOT NULL,
--     type_id integer REFERENCES renumeration_type(id) DEFERRABLE NOT NULL
-- );
-- ALTER TABLE orders.tender OWNER TO www;
-- ALTER TABLE orders.tender OWNER TO www;
-- ALTER TABLE orders.tender ADD UNIQUE (order_id, rank);
-- CREATE INDEX tender_order_idx ON orders.tender ( order_id );
-- CREATE INDEX tender_voucher_code ON orders.tender( voucher_code_id ) WHERE voucher_code_id IS NOT NULL;

INSERT INTO renumeration_type (id, type) VALUES (4,'Voucher Credit'); 

-- sequence not used in table
DROP SEQUENCE renumeration_type_id_seq CASCADE;

-- Check voucher_code is not null when type_id is 'Voucher Credit', and is null when type_id is not
CREATE OR REPLACE FUNCTION tender_voucher_code_not_null()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        IF ( NEW.type_id = ( SELECT id FROM renumeration_type WHERE type='Voucher Credit' ) ) THEN
            IF (NEW.voucher_code_id IS NULL) THEN
                RAISE EXCEPTION 'no voucher code defined for tender of type ''Voucher Credit'' for order_id %', NEW.order_id;
            END IF;
        ELSE
            IF (NEW.voucher_code_id IS NOT NULL) THEN
                RAISE EXCEPTION 'voucher code defined for tender of type other than ''Voucher Credit'' for order_id %', NEW.order_id;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

CREATE TRIGGER check_tender_voucher_code BEFORE INSERT OR UPDATE ON orders.tender FOR EACH ROW EXECUTE PROCEDURE tender_voucher_code_not_null();

COMMIT;
