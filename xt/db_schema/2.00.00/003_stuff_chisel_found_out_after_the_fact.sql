BEGIN;
    -- we're not having a "CLASSIC PROMOTION" type, instead we (the java team)
    -- are using "PROMOTION" + "product_page_visible" to indicate a "classic"
    -- promotion

    -- 1. add the missing product_page_visible column
    ALTER TABLE event.detail
        ADD COLUMN product_page_visible
            boolean DEFAULT true;

    -- update anything that has an event_id for CLASSIC_PROMOTION
    UPDATE event.detail
    SET
        product_page_visible = false,
        event_type_id = ( SELECT id FROM event.type WHERE name = 'Promotion' )
    WHERE
        event_type_id = ( SELECT id FROM event.type WHERE name = 'Classic Promotion' )
    ;

    -- delete the offending entry in the reference table
    DELETE FROM event.type WHERE name = 'Classic Promotion';

    -- add the new REVERSE AUCTION column
    ALTER TABLE event.detail
        ADD COLUMN end_price_drop_date
            timestamp with time zone
                NULL;
COMMIT;
