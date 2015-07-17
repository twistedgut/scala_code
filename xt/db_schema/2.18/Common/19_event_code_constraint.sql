BEGIN;
	CREATE OR REPLACE FUNCTION event_coupon_prefix_check()
	RETURNS TRIGGER AS $$
	BEGIN

	IF NEW.prefix SIMILAR TO 'GC%' THEN
		RAISE EXCEPTION 'coupons cannot be prefixed with "GC"';
	ELSE 
		IF NEW.code SIMILAR TO 'GC%' THEN
			RAISE EXCEPTION 'coupons cannot begin with "GC"';
		END IF;

		RETURN NEW;
	END IF;
	END;
    $$
    LANGUAGE 'plpgsql';

    CREATE TRIGGER check_event_coupon_prefix BEFORE INSERT OR UPDATE ON event.coupon FOR EACH ROW EXECUTE PROCEDURE event_coupon_prefix_check();

	CREATE OR REPLACE FUNCTION event_detail_prefix_check()
	RETURNS TRIGGER AS $$
	BEGIN

	IF NEW.coupon_prefix SIMILAR TO 'GC%' THEN
		RAISE EXCEPTION 'coupons cannot be prefixed with "GC"';
	ELSE 
		RETURN NEW;
	END IF;

	END;
    $$
    LANGUAGE 'plpgsql';

    CREATE TRIGGER check_event_detail_prefix BEFORE INSERT OR UPDATE ON event.detail FOR EACH ROW EXECUTE PROCEDURE event_detail_prefix_check();
COMMIT;
