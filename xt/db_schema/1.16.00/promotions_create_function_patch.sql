-- Casts functions correctly for psql 8.3

BEGIN;

    CREATE OR REPLACE FUNCTION create_promotion_trigger() RETURNS
        trigger AS $$
    BEGIN

        IF (length( CAST(NEW.id AS text) ) > 6) THEN
            -- even though there are claims that there'll never be a million
            -- promotions, let's make sure things don't grind to a halt
            -- if/when it happens
            RAISE NOTICE '...and they said there would never be more than a million promotions!';
            NEW.visible_id := 'PRS-' || NEW.id;
        ELSE
            NEW.visible_id := 'PRS-' || lpad(CAST(NEW.id AS text), 6, '0');
        END IF;

        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

COMMIT;
