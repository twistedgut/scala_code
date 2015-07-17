BEGIN;
    ALTER TABLE promotion.detail
        ADD COLUMN enabled
             boolean     null default null
    ;
COMMIT;
