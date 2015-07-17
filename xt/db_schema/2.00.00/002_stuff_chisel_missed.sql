BEGIN;

    ALTER TABLE event.detail_product
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.detail_seasons
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.detail_designers
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.detail_producttypes
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.detail_products
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.detail_customer
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.detail_customergroup
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.detail_customergroupjoin_listtype
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.detail_websites
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.detail_shippingoptions
        RENAME COLUMN detail_id
            TO event_id
    ;

    ALTER TABLE event.coupon
        RENAME COLUMN detail_id
            TO event_id
    ;

COMMIT;
